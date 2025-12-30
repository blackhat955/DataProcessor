import Foundation

actor DataProfiler {
    func profile(chunk: DataChunk) -> DatasetProfile {
        let rows = chunk.rows
        let schema = chunk.schema
        var columnProfiles: [ColumnProfile] = []
        
        for (index, field) in schema.fields.enumerated() {
            var nullCount = 0
            var uniqueValues: Set<String> = []
            var minVal: Double = .infinity
            var maxVal: Double = -.infinity
            var minDate: Date? = nil
            var maxDate: Date? = nil
            
            for row in rows {
                guard index < row.values.count else {
                    nullCount += 1
                    continue
                }
                
                let val = row.values[index]
                switch val {
                case .null:
                    nullCount += 1
                case .string(let s):
                    uniqueValues.insert(s)
                case .integer(let i):
                    uniqueValues.insert("\(i)")
                    let d = Double(i)
                    if d < minVal { minVal = d }
                    if d > maxVal { maxVal = d }
                case .double(let d):
                    uniqueValues.insert("\(d)")
                    if d < minVal { minVal = d }
                    if d > maxVal { maxVal = d }
                case .boolean(let b):
                    uniqueValues.insert("\(b)")
                case .date(let d):
                    uniqueValues.insert(d.ISO8601Format())
                    if minDate == nil || d < minDate! { minDate = d }
                    if maxDate == nil || d > maxDate! { maxDate = d }
                }
            }
            
            let profile = ColumnProfile(
                columnName: field.name,
                type: field.type,
                nullCount: nullCount,
                totalCount: rows.count,
                uniqueCount: uniqueValues.count,
                min: minVal == .infinity ? nil : minVal,
                max: maxVal == -.infinity ? nil : maxVal,
                minDate: minDate,
                maxDate: maxDate
            )
            columnProfiles.append(profile)
        }
        
        let type = classifyDataset(profiles: columnProfiles)
        return DatasetProfile(rowCount: rows.count, columnProfiles: columnProfiles, datasetType: type)
    }
    
    private func classifyDataset(profiles: [ColumnProfile]) -> DatasetType {
        // 1. Time Series: Has a Date column with high cardinality (many unique timestamps)
        let dateCols = profiles.filter { $0.type == .date }
        if let primaryDate = dateCols.first, primaryDate.cardinality == .high || primaryDate.cardinality == .medium {
            return .timeSeries
        }
        
        // 2. Transactional: Has Date + High Cardinality ID (String/Int) + Numeric Values
        let idCols = profiles.filter { ($0.type == .string || $0.type == .integer) && $0.cardinality == .high }
        let numericCols = profiles.filter { ($0.type == .integer || $0.type == .double) && $0.cardinality != .low }
        if !dateCols.isEmpty && !idCols.isEmpty && !numericCols.isEmpty {
            return .transactional
        }
        
        // 3. Categorical: Mostly low cardinality strings + some numbers
        let lowCardCols = profiles.filter { $0.cardinality == .low }
        if Double(lowCardCols.count) / Double(profiles.count) > 0.5 {
            return .categorical
        }
        
        // 4. Log: Date + Message (High card string)
        let longStringCols = profiles.filter { $0.type == .string && $0.cardinality == .high }
        if !dateCols.isEmpty && !longStringCols.isEmpty {
            return .log
        }
        
        return .unknown
    }
}
