import Foundation

actor JSONExtractor: DataSource {
    let url: URL
    let chunkSize: Int
    
    init(url: URL, chunkSize: Int = 1000) {
        self.url = url
        self.chunkSize = chunkSize
    }
    
    func preview(rows: Int) async throws -> ([Row], Schema) {
        // For preview, we'll try to read the first few objects
        // This is a naive implementation that assumes JSON Array or JSON Lines
        // For robust production use, a streaming parser is needed.
        // Here we attempt to load a small portion of the file.
        
        let (data, _) = try await readBytes(limit: 1024 * 1024) // Read 1MB max for preview
        
        // Try parsing as generic JSON
        var jsonObjects: [[String: Any]] = []
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            if let array = json as? [[String: Any]] {
                jsonObjects = Array(array.prefix(rows))
            } else if let dict = json as? [String: Any] {
                jsonObjects = [dict]
            }
        } else {
            // Try JSON Lines (NDJSON)
            if let string = String(data: data, encoding: .utf8) {
                let lines = string.components(separatedBy: .newlines)
                for line in lines.prefix(rows) {
                    if let lineData = line.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any] {
                        jsonObjects.append(dict)
                    }
                }
            }
        }
        
        guard !jsonObjects.isEmpty else { throw DataSourceError.invalidFormat }
        
        // Infer Schema
        let schema = inferSchema(from: jsonObjects)
        
        // Convert to Rows
        let resultRows = jsonObjects.map { dict in
            rowFromDict(dict, schema: schema)
        }
        
        return (resultRows, schema)
    }
    
    nonisolated func stream(schema: Schema? = nil) -> AsyncThrowingStream<DataChunk, Error> {
        let fileURL = self.url
        let fileChunkSize = self.chunkSize
        
        return AsyncThrowingStream { continuation in
            Task {
                var accessGranted = false
                do {
                    // Security Scope
                    if fileURL.isFileURL {
                        accessGranted = fileURL.startAccessingSecurityScopedResource()
                    }
                    
                    // Determine Schema (must be passed or re-inferred, simplified here)
                    // We assume schema is passed or we'll infer from the first chunk roughly
                    var finalSchema = schema ?? Schema(fields: [])
                    
                    // For streaming, we strictly support JSON Lines (NDJSON) or "Small" JSON Arrays
                    // Large JSON Arrays [ ... ] are hard to stream without a tokenizer.
                    // We will implement NDJSON streaming here as it's the standard for ETL.
                    
                    // Note: If the file is a standard JSON Array, this line iterator will likely fail 
                    // or return the whole file as one line if minified.
                    
                    var rowBuffer: [Row] = []
                    var isFirstChunk = true
                    
                    for try await line in fileURL.lines {
                        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                        
                        if let data = line.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            
                            // Lazy Schema Inference if missing
                            if finalSchema.fields.isEmpty {
                                finalSchema = inferSchema(from: [dict])
                            }
                            
                            let row = rowFromDict(dict, schema: finalSchema)
                            rowBuffer.append(row)
                        }
                        
                        if rowBuffer.count >= fileChunkSize {
                            continuation.yield(DataChunk(id: UUID(), rows: rowBuffer, schema: finalSchema))
                            rowBuffer = []
                        }
                    }
                    
                    if !rowBuffer.isEmpty {
                        continuation.yield(DataChunk(id: UUID(), rows: rowBuffer, schema: finalSchema))
                    }
                    
                    if accessGranted { fileURL.stopAccessingSecurityScopedResource() }
                    continuation.finish()
                    
                } catch {
                    if accessGranted { fileURL.stopAccessingSecurityScopedResource() }
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func readBytes(limit: Int) async throws -> (Data, Bool) {
        // Read up to limit bytes
        let handle = try FileHandle(forReadingFrom: url)
        let data = try handle.read(upToCount: limit) ?? Data()
        try handle.close()
        return (data, data.count >= limit)
    }
    
    private nonisolated func inferSchema(from objects: [[String: Any]]) -> Schema {
        var fields: [String: ColumnType] = [:]
        var keys: Set<String> = []
        
        // Collect all keys
        for obj in objects {
            for key in obj.keys {
                keys.insert(key)
            }
        }
        
        // Infer types
        for key in keys {
            var type: ColumnType = .unknown
            
            for obj in objects {
                if let val = obj[key] {
                    let inferred = inferType(val)
                    if type == .unknown {
                        type = inferred
                    } else if type != inferred && inferred != .unknown {
                        // Conflict resolution: default to string if mixed
                        // e.g. Int vs Double -> Double
                        if (type == .integer && inferred == .double) || (type == .double && inferred == .integer) {
                            type = .double
                        } else {
                            type = .string
                        }
                    }
                }
            }
            fields[key] = type
        }
        
        let schemaFields = fields.map { Schema.Field(name: $0.key, type: $0.value) }.sorted { $0.name < $1.name }
        return Schema(fields: schemaFields)
    }
    
    private nonisolated func inferType(_ value: Any) -> ColumnType {
        switch value {
        case is Int: return .integer
        case is Double: return .double
        case is Bool: return .boolean
        case is String: return .string
        default: return .string
        }
    }
    
    private nonisolated func rowFromDict(_ dict: [String: Any], schema: Schema) -> Row {
        let values = schema.fields.map { field -> DataValue in
            guard let rawVal = dict[field.name] else { return .null }
            
            switch field.type {
            case .integer:
                if let v = rawVal as? Int { return .integer(v) }
                if let v = rawVal as? Double { return .integer(Int(v)) }
            case .double:
                if let v = rawVal as? Double { return .double(v) }
                if let v = rawVal as? Int { return .double(Double(v)) }
            case .boolean:
                if let v = rawVal as? Bool { return .boolean(v) }
            case .string:
                if let v = rawVal as? String { return .string(v) }
            default: break
            }
            return .string("\(rawVal)")
        }
        return Row(values: values)
    }
}
