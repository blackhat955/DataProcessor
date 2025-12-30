import Foundation

enum TransformType: String, Codable, Sendable {
    case filter
    case select
    case rename
    case sort
    case text
    case math
    case findReplace
}

protocol TransformOperation: Sendable {
    var id: UUID { get }
    var type: TransformType { get }
    
    func apply(to chunk: DataChunk) async throws -> DataChunk
}

// MARK: - Filter Transform

enum FilterOperator: String, Codable, Sendable {
    case equals
    case notEquals
    case greaterThan
    case lessThan
    case contains
}

struct FilterCondition: Codable, Sendable {
    let column: String
    let op: FilterOperator
    let value: String // Comparison value as string for simplicity
}

struct FilterTransform: TransformOperation {
    let id = UUID()
    let type: TransformType = .filter
    let condition: FilterCondition
    
    func apply(to chunk: DataChunk) async throws -> DataChunk {
        guard let colIndex = chunk.schema.index(of: condition.column) else {
            return chunk // Column not found, return as is or throw
        }
        
        let filteredRows = chunk.rows.filter { row in
            guard let cellValue = row[colIndex] else { return false }
            return evaluate(cellValue, condition: condition)
        }
        
        return DataChunk(id: chunk.id, rows: filteredRows, schema: chunk.schema)
    }
    
    private func evaluate(_ value: DataValue, condition: FilterCondition) -> Bool {
        let strValue = value.description
        
        switch condition.op {
        case .equals: return strValue == condition.value
        case .notEquals: return strValue != condition.value
        case .contains: return strValue.contains(condition.value)
        case .greaterThan:
            if let v = Double(strValue), let c = Double(condition.value) { return v > c }
            return strValue > condition.value
        case .lessThan:
            if let v = Double(strValue), let c = Double(condition.value) { return v < c }
            return strValue < condition.value
        }
    }
}

// MARK: - Select Transform

struct SelectTransform: TransformOperation {
    let id = UUID()
    let type: TransformType = .select
    let columns: [String]
    
    func apply(to chunk: DataChunk) async throws -> DataChunk {
        let indices = columns.compactMap { chunk.schema.index(of: $0) }
        
        let newFields = indices.map { chunk.schema.fields[$0] }
        let newSchema = Schema(fields: newFields)
        
        let newRows = chunk.rows.map { row in
            let newValues = indices.map { row.values[$0] }
            return Row(id: row.id, values: newValues)
        }
        
        return DataChunk(id: chunk.id, rows: newRows, schema: newSchema)
    }
}

// MARK: - Rename Transform

struct RenameTransform: TransformOperation {
    let id = UUID()
    let type: TransformType = .rename
    let mapping: [String: String] // Old Name -> New Name
    
    func apply(to chunk: DataChunk) async throws -> DataChunk {
        let newFields = chunk.schema.fields.map { field in
            if let newName = mapping[field.name] {
                return Schema.Field(name: newName, type: field.type)
            }
            return field
        }
        
        return DataChunk(id: chunk.id, rows: chunk.rows, schema: Schema(fields: newFields))
    }
}

// MARK: - Sort Transform

enum SortOrder: String, Codable, Sendable {
    case ascending
    case descending
}

struct SortTransform: TransformOperation {
    let id = UUID()
    let type: TransformType = .sort
    let column: String
    let order: SortOrder
    
    func apply(to chunk: DataChunk) async throws -> DataChunk {
        guard let colIndex = chunk.schema.index(of: column) else { return chunk }
        
        let sortedRows = chunk.rows.sorted { row1, row2 in
            guard let val1 = row1[colIndex], let val2 = row2[colIndex] else { return false }
            
            let isLess: Bool
            switch (val1, val2) {
            case let (.integer(i1), .integer(i2)): isLess = i1 < i2
            case let (.double(d1), .double(d2)): isLess = d1 < d2
            case let (.string(s1), .string(s2)): isLess = s1 < s2
            default: isLess = val1.description < val2.description
            }
            
            return order == .ascending ? isLess : !isLess
        }
        
        return DataChunk(id: chunk.id, rows: sortedRows, schema: chunk.schema)
    }
}

// MARK: - Text Transform

enum TextOperation: String, Codable, Sendable {
    case uppercase
    case lowercase
    case capitalize
    case trim
}

struct TextTransform: TransformOperation {
    let id = UUID()
    let type: TransformType = .text
    let column: String
    let operation: TextOperation
    
    func apply(to chunk: DataChunk) async throws -> DataChunk {
        guard let colIndex = chunk.schema.index(of: column) else { return chunk }
        
        let newRows = chunk.rows.map { row in
            var newRow = row
            if let val = row[colIndex] {
                let strVal = val.description
                let newVal: String
                switch operation {
                case .uppercase: newVal = strVal.uppercased()
                case .lowercase: newVal = strVal.lowercased()
                case .capitalize: newVal = strVal.capitalized
                case .trim: newVal = strVal.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                newRow.values[colIndex] = .string(newVal)
            }
            return newRow
        }
        
        // Update schema type for this column to String
        var newFields = chunk.schema.fields
        newFields[colIndex] = Schema.Field(name: newFields[colIndex].name, type: .string)
        let newSchema = Schema(fields: newFields)
        
        return DataChunk(id: chunk.id, rows: newRows, schema: newSchema)
    }
}

// MARK: - Math Transform

enum MathOperation: String, Codable, Sendable {
    case add
    case subtract
    case multiply
    case divide
    case power
    case modulo
    case round
    case floor
    case ceil
}

struct MathTransform: TransformOperation {
    let id = UUID()
    let type: TransformType = .math
    let column: String
    let operation: MathOperation
    let value: Double
    
    func apply(to chunk: DataChunk) async throws -> DataChunk {
        guard let colIndex = chunk.schema.index(of: column) else { return chunk }
        
        let newRows = chunk.rows.map { row in
            var newRow = row
            if let val = row[colIndex] {
                var doubleVal: Double = 0
                switch val {
                case .integer(let i): doubleVal = Double(i)
                case .double(let d): doubleVal = d
                case .string(let s): doubleVal = Double(s) ?? 0
                default: break
                }
                
                let result: Double
                switch operation {
                case .add: result = doubleVal + value
                case .subtract: result = doubleVal - value
                case .multiply: result = doubleVal * value
                case .divide: result = value != 0 ? doubleVal / value : 0
                case .power: result = pow(doubleVal, value)
                case .modulo: result = value != 0 ? doubleVal.truncatingRemainder(dividingBy: value) : 0
                case .round: result = doubleVal.rounded()
                case .floor: result = doubleVal.rounded(.down)
                case .ceil: result = doubleVal.rounded(.up)
                }
                
                // Preserve original type if integer
                if case .integer = val {
                    newRow.values[colIndex] = .integer(Int(result))
                } else {
                    newRow.values[colIndex] = .double(result)
                }
            }
            return newRow
        }
        
        // Update schema type based on operation/input
        // For simplicity, we assume Math operations generally result in Double unless it was Integer and stayed Integer
        // But since we can't easily track per-row type changes in schema (schema is global for chunk), 
        // we should promote to Double if it's not strictly integer-safe or if we can't guarantee.
        // However, the code above tries to preserve Integer.
        // Let's check the field type.
        
        var newFields = chunk.schema.fields
        let currentType = newFields[colIndex].type
        
        // If it was String, we converted to Double, so schema MUST be updated to Double/Integer
        if currentType == .string {
             newFields[colIndex] = Schema.Field(name: newFields[colIndex].name, type: .double)
        }
        // If it was Integer, and we did division/power, it might need to become Double?
        // But the row logic casts back to Int if input was Int. 
        // So keeping Integer is fine if the row logic ensures Int.
        
        let newSchema = Schema(fields: newFields)
        
        return DataChunk(id: chunk.id, rows: newRows, schema: newSchema)
    }
}

// MARK: - Find & Replace Transform

struct FindReplaceTransform: TransformOperation {
    let id = UUID()
    let type: TransformType = .findReplace
    let column: String
    let findText: String
    let replaceText: String
    let isCaseSensitive: Bool
    
    func apply(to chunk: DataChunk) async throws -> DataChunk {
        guard let colIndex = chunk.schema.index(of: column) else { return chunk }
        
        let newRows = chunk.rows.map { row in
            var newRow = row
            if let val = row[colIndex] {
                let strVal = val.description
                let options: String.CompareOptions = isCaseSensitive ? [] : .caseInsensitive
                let newVal = strVal.replacingOccurrences(of: findText, with: replaceText, options: options)
                newRow.values[colIndex] = .string(newVal)
            }
            return newRow
        }
        
        // Update schema type to String
        var newFields = chunk.schema.fields
        newFields[colIndex] = Schema.Field(name: newFields[colIndex].name, type: .string)
        let newSchema = Schema(fields: newFields)
        
        return DataChunk(id: chunk.id, rows: newRows, schema: newSchema)
    }
}




