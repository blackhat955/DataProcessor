import Foundation

/// Represents the data type of a column
enum ColumnType: String, Codable, CaseIterable, Sendable {
    case string
    case integer
    case double
    case boolean
    case date
    case unknown
}

/// Represents a single cell value
enum DataValue: Codable, Hashable, CustomStringConvertible, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case date(Date)
    case null
    
    var description: String {
        switch self {
        case .string(let v): return v
        case .integer(let v): return String(v)
        case .double(let v): return String(v)
        case .boolean(let v): return String(v)
        case .date(let v): return v.ISO8601Format()
        case .null: return ""
        }
    }
}

/// Defines the structure of the dataset
struct Schema: Codable, Equatable, Sendable {
    struct Field: Codable, Equatable, Identifiable, Sendable {
        var id: String { name }
        let name: String
        var type: ColumnType
    }
    
    var fields: [Field]
    
    func index(of fieldName: String) -> Int? {
        fields.firstIndex { $0.name == fieldName }
    }
}

/// Represents a single row of data
struct Row: Identifiable, Codable, Sendable {
    let id: UUID
    var values: [DataValue]
    
    init(id: UUID = UUID(), values: [DataValue]) {
        self.id = id
        self.values = values
    }
    
    subscript(index: Int) -> DataValue? {
        guard index >= 0 && index < values.count else { return nil }
        return values[index]
    }
}

/// Represents a chunk of data for processing
struct DataChunk: Sendable {
    let id: UUID
    let rows: [Row]
    let schema: Schema
}
