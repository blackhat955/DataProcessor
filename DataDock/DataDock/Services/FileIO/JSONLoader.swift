import Foundation

actor JSONLoader: Loader {
    let url: URL
    let isPretty: Bool
    private var fileHandle: FileHandle?
    private var isFirstChunk = true
    private var isNDJSON = true // Default to Newline Delimited JSON for streaming support
    
    init(url: URL, isPretty: Bool = false) {
        self.url = url
        self.isPretty = isPretty
        self.isNDJSON = url.pathExtension.lowercased() == "ndjson" || url.pathExtension.lowercased() == "jsonl"
        // If regular .json, we still default to NDJSON for streaming safety in this prototype,
        // OR we can implement Array writing.
        // Let's implement Array writing for .json and NDJSON for .jsonl
        if url.pathExtension.lowercased() == "json" {
            self.isNDJSON = false
        }
    }
    
    func prepare() async throws {
        _ = url.startAccessingSecurityScopedResource()
        
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        fileHandle = try FileHandle(forWritingTo: url)
        fileHandle?.truncateFile(atOffset: 0)
        
        if !isNDJSON {
            // Start Array
            try fileHandle?.write(contentsOf: Data("[".utf8))
            if isPretty { try fileHandle?.write(contentsOf: Data("\n".utf8)) }
        }
    }
    
    func write(chunk: DataChunk) async throws {
        guard let handle = fileHandle else { return }
        
        for (index, row) in chunk.rows.enumerated() {
            // Add comma if not first item (for Array format)
            if !isNDJSON {
                if !isFirstChunk || index > 0 {
                    let separator = isPretty ? ",\n" : ","
                    try handle.write(contentsOf: Data(separator.utf8))
                }
            }
            
            let dict = rowToDict(row, schema: chunk.schema)
            let options: JSONSerialization.WritingOptions = isPretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
            
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: options) {
                try handle.write(contentsOf: data)
                if isNDJSON {
                    try handle.write(contentsOf: Data("\n".utf8))
                }
            }
        }
        
        isFirstChunk = false
    }
    
    func finish() async throws {
        if !isNDJSON {
            // End Array
            if isPretty { try fileHandle?.write(contentsOf: Data("\n".utf8)) }
            try fileHandle?.write(contentsOf: Data("]".utf8))
        }
        
        try fileHandle?.close()
        fileHandle = nil
        url.stopAccessingSecurityScopedResource()
    }
    
    private func rowToDict(_ row: Row, schema: Schema) -> [String: Any] {
        var dict: [String: Any] = [:]
        for (index, field) in schema.fields.enumerated() {
            guard index < row.values.count else { continue }
            let val = row.values[index]
            
            switch val {
            case .integer(let v): dict[field.name] = v
            case .double(let v): dict[field.name] = v
            case .boolean(let v): dict[field.name] = v
            case .string(let v): dict[field.name] = v
            case .date(let v): dict[field.name] = v.ISO8601Format()
            case .null: dict[field.name] = nil
            }
        }
        return dict
    }
}
