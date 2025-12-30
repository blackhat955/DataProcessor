import Foundation
import SQLite3

enum SQLiteError: Error {
    case openFailed(message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case bindFailed(message: String)
    case execFailed(message: String)
}

class SQLiteDatabase {
    private var db: OpaquePointer?
    
    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw SQLiteError.openFailed(message: errorMessage)
        }
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    var errorMessage: String {
        if let errorPointer = sqlite3_errmsg(db) {
            return String(cString: errorPointer)
        }
        return "Unknown error"
    }
    
    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let message = error != nil ? String(cString: error!) : "Unknown exec error"
            sqlite3_free(error)
            throw SQLiteError.execFailed(message: message)
        }
    }
    
    func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteError.prepareFailed(message: errorMessage)
        }
        return statement
    }
    
    // Transaction helpers
    func beginTransaction() throws { try execute("BEGIN TRANSACTION") }
    func commit() throws { try execute("COMMIT") }
    func rollback() throws { try execute("ROLLBACK") }
}
