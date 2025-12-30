import Foundation

actor CSVLoader: Loader {
    let url: URL
    private var fileHandle: FileHandle?
    private var isFirstChunk = true
    
    init(url: URL) {
        self.url = url
    }
    
    func prepare() async throws {
        // Start accessing
        _ = url.startAccessingSecurityScopedResource()
        
        // Create file if not exists
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        fileHandle = try FileHandle(forWritingTo: url)
        fileHandle?.truncateFile(atOffset: 0)
    }
    
    func write(chunk: DataChunk) async throws {
        guard let handle = fileHandle else { return }
        
        var data = Data()
        
        // Write header if first chunk
        if isFirstChunk {
            let header = chunk.schema.fields.map { $0.name }.joined(separator: ",") + "\n"
            if let headerData = header.data(using: .utf8) {
                data.append(headerData)
            }
            isFirstChunk = false
        }
        
        // Write rows
        for row in chunk.rows {
            let line = row.values.map { val in
                switch val {
                case .string(let v): return v
                case .integer(let v): return String(v)
                case .double(let v): return String(v)
                case .boolean(let v): return String(v)
                case .date(let v): return v.ISO8601Format()
                case .null: return ""
                }
            }.joined(separator: ",") + "\n"
            
            if let lineData = line.data(using: .utf8) {
                data.append(lineData)
            }
        }
        
        try handle.write(contentsOf: data)
    }
    
    func finish() async throws {
        try fileHandle?.close()
        fileHandle = nil
        url.stopAccessingSecurityScopedResource()
    }
}
