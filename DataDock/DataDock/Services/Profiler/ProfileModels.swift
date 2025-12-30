import Foundation

struct ColumnProfile: Sendable {
    let columnName: String
    let type: ColumnType
    let nullCount: Int
    let totalCount: Int
    let uniqueCount: Int
    let min: Double?
    let max: Double?
    let minDate: Date?
    let maxDate: Date?
    
    var nullPercentage: Double {
        return totalCount > 0 ? Double(nullCount) / Double(totalCount) : 0.0
    }
    
    var cardinality: Cardinality {
        let uniqueRatio = totalCount > 0 ? Double(uniqueCount) / Double(totalCount) : 0.0
        if uniqueRatio < 0.01 || uniqueCount < 20 { return .low } // Categorical
        if uniqueRatio > 0.9 { return .high } // Unique ID
        return .medium
    }
    
    enum Cardinality {
        case low, medium, high
    }
}

enum DatasetType: String, Sendable {
    case transactional = "Transactional"
    case timeSeries = "Time Series"
    case categorical = "Categorical Aggregation"
    case log = "Log Data"
    case unknown = "Unknown"
}

struct DatasetProfile: Sendable {
    let rowCount: Int
    let columnProfiles: [ColumnProfile]
    let datasetType: DatasetType
}
