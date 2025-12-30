import Foundation

actor NetworkExtractor: DataSource {
    let url: URL
    let delimiter: String
    let hasHeader: Bool
    let chunkSize: Int
    
    init(url: URL, delimiter: String = ",", hasHeader: Bool = true, chunkSize: Int = 1000) {
        self.url = url
        self.delimiter = delimiter
        self.hasHeader = hasHeader
        self.chunkSize = chunkSize
    }
    
    func preview(rows: Int) async throws -> ([Row], Schema) {
        // For network, we just grab the first few lines
        // URLSession.shared.data(from: url) might download the whole file which is bad for large files.
        // url.lines is streaming!
        
        var lines: [String] = []
        var iterator = url.lines.makeAsyncIterator()
        
        // Read header
        guard let first = try await iterator.next() else {
            throw DataSourceError.emptyFile
        }
        
        // Read body
        while lines.count < rows {
            if let line = try await iterator.next() {
                lines.append(line)
            } else {
                break
            }
        }
        
        let headers = hasHeader ? parseLine(first) : (0..<parseLine(lines.first ?? "").count).map { "Column \($0 + 1)" }
        let dataLines = hasHeader ? lines : [first] + lines
        
        // Infer schema
        let parsedRows = dataLines.prefix(rows).map { parseLine($0) }
        let schema = inferSchema(headers: headers, rows: parsedRows)
        
        // Convert to Rows
        let resultRows = parsedRows.map { values in
            Row(values: zip(values, schema.fields).map { val, field in
                parseValue(val, type: field.type)
            })
        }
        
        return (resultRows, schema)
    }
    
    nonisolated func stream(schema: Schema? = nil) -> AsyncThrowingStream<DataChunk, Error> {
        let fileURL = self.url
        let fileHasHeader = self.hasHeader
        let fileChunkSize = self.chunkSize
        let fileDelimiter = self.delimiter
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Network does not need security scope
                    
                    // Determine schema
                    let finalSchema: Schema
                    if let s = schema {
                        finalSchema = s
                    } else {
                        // Fallback inference if not provided
                        // This is a simplified inference for stream start
                        var lines: [String] = []
                        for try await line in fileURL.lines {
                            lines.append(line)
                            if lines.count >= 50 { break }
                        }
                        let headers = fileHasHeader ? lines.first?.components(separatedBy: fileDelimiter) ?? [] : []
                        finalSchema = Schema(fields: headers.map { Schema.Field(name: $0, type: .string) }) // simplified
                    }
                    
                    var rowBuffer: [Row] = []
                    var isFirstLine = true
                    
                    for try await line in fileURL.lines {
                        if isFirstLine {
                            isFirstLine = false
                            if fileHasHeader { continue }
                        }
                        
                        let values = line.components(separatedBy: fileDelimiter)
                        if values.count == finalSchema.fields.count {
                            let rowValues = zip(values, finalSchema.fields).map { val, field in
                                // parseValue logic inline
                                switch field.type {
                                case .integer: return DataValue.integer(Int(val) ?? 0)
                                case .double: return DataValue.double(Double(val) ?? 0.0)
                                case .boolean: return DataValue.boolean(["true", "yes", "1"].contains(val.lowercased()))
                                default: return DataValue.string(val)
                                }
                            }
                            rowBuffer.append(Row(values: rowValues))
                        }
                        
                        if rowBuffer.count >= fileChunkSize {
                            continuation.yield(DataChunk(id: UUID(), rows: rowBuffer, schema: finalSchema))
                            rowBuffer = []
                        }
                    }
                    
                    if !rowBuffer.isEmpty {
                        continuation.yield(DataChunk(id: UUID(), rows: rowBuffer, schema: finalSchema))
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helpers (Duplicated from CSVExtractor for independence)
    
    private func parseLine(_ line: String) -> [String] {
        return line.components(separatedBy: delimiter)
    }
    
    private func inferSchema(headers: [String], rows: [[String]]) -> Schema {
        var fields: [Schema.Field] = []
        for (index, name) in headers.enumerated() {
            var detectedType: ColumnType = .unknown
            let columnValues = rows.compactMap { $0.indices.contains(index) ? $0[index] : nil }
            
            if columnValues.isEmpty { detectedType = .string }
            else if columnValues.allSatisfy({ Int($0) != nil }) { detectedType = .integer }
            else if columnValues.allSatisfy({ Double($0) != nil }) { detectedType = .double }
            else if columnValues.allSatisfy({ ["true", "false", "yes", "no"].contains($0.lowercased()) }) { detectedType = .boolean }
            else { detectedType = .string }
            
            fields.append(Schema.Field(name: name, type: detectedType))
        }
        return Schema(fields: fields)
    }
    
    private func parseValue(_ value: String, type: ColumnType) -> DataValue {
        switch type {
        case .integer: return .integer(Int(value) ?? 0)
        case .double: return .double(Double(value) ?? 0.0)
        case .boolean: return .boolean(["true", "yes", "1"].contains(value.lowercased()))
        default: return .string(value)
        }
    }
}
