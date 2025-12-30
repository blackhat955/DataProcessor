import Foundation
import SQLite3

internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

actor SQLiteLoader: Loader {
    let dbPath: String
    let tableName: String
    private var db: SQLiteDatabase?
    private var insertStatement: OpaquePointer?
    
    init(dbPath: String, tableName: String = "data_dock_export") {
        self.dbPath = dbPath
        self.tableName = tableName
    }
    
    func prepare() async throws {
        // Ensure directory exists
        let directory = URL(fileURLWithPath: dbPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        db = try SQLiteDatabase(path: dbPath)
    }
    
    func write(chunk: DataChunk) async throws {
        guard let db = db else { return }
        
        // If first chunk (lazy init of table and statement), create table
        if insertStatement == nil {
            try createTable(schema: chunk.schema)
            let placeholders = Array(repeating: "?", count: chunk.schema.fields.count).joined(separator: ",")
            let sql = "INSERT INTO \(tableName) VALUES (\(placeholders))"
            insertStatement = try db.prepare(sql)
        }
        
        try db.beginTransaction()
        
        for row in chunk.rows {
            guard let stmt = insertStatement else { continue }
            
            sqlite3_reset(stmt)
            
            for (index, val) in row.values.enumerated() {
                let idx = Int32(index + 1)
                switch val {
                case .integer(let v): sqlite3_bind_int64(stmt, idx, Int64(v))
                case .double(let v): sqlite3_bind_double(stmt, idx, v)
                case .boolean(let v): sqlite3_bind_int(stmt, idx, v ? 1 : 0)
                case .string(let v): 
                    sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, SQLITE_TRANSIENT)
                case .date(let v):
                     sqlite3_bind_text(stmt, idx, (v.ISO8601Format() as NSString).utf8String, -1, SQLITE_TRANSIENT)
                case .null: sqlite3_bind_null(stmt, idx)
                }
            }
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                throw SQLiteError.stepFailed(message: db.errorMessage)
            }
        }
        
        try db.commit()
    }
    
    func finish() async throws {
        if let stmt = insertStatement {
            sqlite3_finalize(stmt)
            insertStatement = nil
        }
        db = nil // Close connection
    }
    
    private func createTable(schema: Schema) throws {
        var columns: [String] = []
        for field in schema.fields {
            let typeStr: String
            switch field.type {
            case .integer: typeStr = "INTEGER"
            case .double: typeStr = "REAL"
            case .boolean: typeStr = "INTEGER" // SQLite uses 0/1
            default: typeStr = "TEXT"
            }
            // Sanitize column name to avoid SQL injection or syntax errors
            let safeName = field.name.replacingOccurrences(of: "\"", with: "\"\"")
            columns.append("\"\(safeName)\" \(typeStr)")
        }
        
        // DROP table first to ensure schema matches the new pipeline configuration
        try db?.execute("DROP TABLE IF EXISTS \(tableName)")
        
        let sql = "CREATE TABLE \(tableName) (\(columns.joined(separator: ", ")))"
        try db?.execute(sql)
    }
}
