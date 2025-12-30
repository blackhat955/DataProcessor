import Foundation

struct Suggestion: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let transform: TransformOperation
    let isAI: Bool // New flag
    
    init(title: String, description: String, transform: TransformOperation, isAI: Bool = false) {
        self.title = title
        self.description = description
        self.transform = transform
        self.isAI = isAI
    }
}

struct TransformationSuggester {
    static func suggest(from profile: DatasetProfile) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        for col in profile.columnProfiles {
            // Suggestion 1: Impute Nulls
            if col.nullPercentage > 0.05 {
                // For numeric, suggest mean/zero? (We don't have mean transform yet, so maybe filter or fill)
                // Let's suggest Filter for now or FindReplace if string
                if col.type == .string {
                    let replace = FindReplaceTransform(column: col.columnName, findText: "", replaceText: "Unknown", isCaseSensitive: false)
                    suggestions.append(Suggestion(title: "Fill Missing \(col.columnName)", description: "Replace empty values with 'Unknown'", transform: replace))
                }
            }
            
            // Suggestion 2: Filter Outliers (Negative values in what looks like count/price)
            if (col.type == .integer || col.type == .double) && (col.min ?? 0) < 0 {
                // If mostly positive but some negative? Hard to know without distribution.
                // But we can suggest absolute value or filter.
                // Added suggestion to filter negative values
                let filter = FilterTransform(condition: FilterCondition(column: col.columnName, op: .greaterThan, value: "0"))
                suggestions.append(Suggestion(title: "Filter Negative \(col.columnName)", description: "Keep only positive values", transform: filter))
            }
            
            // Suggestion 3: High Cardinality String -> Maybe it's an ID, do nothing.
            
            // Suggestion 4: Low Cardinality String -> Filter by specific categories?
            
            // Suggestion 5: Math on Numeric
            if col.type == .double {
                 let round = MathTransform(column: col.columnName, operation: .round, value: 0)
                 suggestions.append(Suggestion(title: "Round \(col.columnName)", description: "Round decimal values to nearest integer", transform: round))
            }
        }
        
        // Dataset Level Suggestions
        switch profile.datasetType {
        case .timeSeries:
             // Suggest sorting by date
             if let dateCol = profile.columnProfiles.first(where: { $0.type == .date }) {
                 let sort = SortTransform(column: dateCol.columnName, order: .ascending)
                 suggestions.append(Suggestion(title: "Sort by Time", description: "Order rows chronologically", transform: sort))
             }
        case .transactional:
             break
        default: break
        }
        
        return suggestions
    }
}
