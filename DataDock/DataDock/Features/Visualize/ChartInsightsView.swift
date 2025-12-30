import SwiftUI

struct ChartInsightsView: View {
    let schema: Schema
    let rows: [Row]
    let selectedX: String
    let selectedY: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
            
            if selectedY.isEmpty {
                Text("Select a Value column (Y-Axis) to see insights.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let stats = calculateStats()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    InsightCard(title: "Average", value: stats.average)
                    InsightCard(title: "Total", value: stats.sum)
                    InsightCard(title: "Maximum", value: stats.max)
                    InsightCard(title: "Minimum", value: stats.min)
                }
                
                if !selectedX.isEmpty {
                    Divider()
                    Text("Distribution by \(selectedX)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Showing data for \(stats.count) items across \(stats.uniqueCategories) categories.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private struct Stats {
        let average: String
        let sum: String
        let max: String
        let min: String
        let count: Int
        let uniqueCategories: Int
    }
    
    private func calculateStats() -> Stats {
        guard let yIndex = schema.index(of: selectedY) else {
            return Stats(average: "-", sum: "-", max: "-", min: "-", count: 0, uniqueCategories: 0)
        }
        
        var sum: Double = 0
        var maxVal: Double = -.infinity
        var minVal: Double = .infinity
        var count: Int = 0
        var categories: Set<String> = []
        
        let xIndex = schema.index(of: selectedX)
        
        for row in rows {
            // Get Y Value
            if let val = row[yIndex] {
                let doubleVal: Double
                switch val {
                case .integer(let i): doubleVal = Double(i)
                case .double(let d): doubleVal = d
                case .string(let s): doubleVal = Double(s) ?? 0
                default: doubleVal = 0
                }
                
                sum += doubleVal
                if doubleVal > maxVal { maxVal = doubleVal }
                if doubleVal < minVal { minVal = doubleVal }
                count += 1
            }
            
            // Get X Category
            if let idx = xIndex, let val = row[idx] {
                categories.insert(val.description)
            }
        }
        
        let avg = count > 0 ? sum / Double(count) : 0
        
        // Format
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        return Stats(
            average: formatter.string(from: NSNumber(value: avg)) ?? "-",
            sum: formatter.string(from: NSNumber(value: sum)) ?? "-",
            max: formatter.string(from: NSNumber(value: maxVal)) ?? "-",
            min: formatter.string(from: NSNumber(value: minVal)) ?? "-",
            count: count,
            uniqueCategories: categories.count
        )
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}
