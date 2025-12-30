import SwiftUI

struct VisualizationDetailView: View {
    let originalSchema: Schema
    let originalRows: [Row]
    let transformedSchema: Schema
    let transformedRows: [Row]
    
    @State private var dataMode: DataMode = .transformed
    @State private var selectedX: String = ""
    @State private var selectedY: String = ""
    @State private var chartType: ChartType = .bar
    
    enum DataMode: String, CaseIterable, Identifiable {
        case original = "Original"
        case transformed = "Transformed"
        var id: Self { self }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Data Source", selection: $dataMode) {
                    ForEach(DataMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                DataChartView(
                    schema: activeSchema,
                    rows: activeRows,
                    minHeight: 400,
                    selectedX: $selectedX,
                    selectedY: $selectedY,
                    chartType: $chartType
                )
                .id(dataMode) // Force refresh when toggling data source
                
                ChartInsightsView(
                    schema: activeSchema,
                    rows: activeRows,
                    selectedX: selectedX,
                    selectedY: selectedY
                )
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Data Visualization")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var activeSchema: Schema {
        switch dataMode {
        case .original: return originalSchema
        case .transformed: return transformedSchema
        }
    }
    
    var activeRows: [Row] {
        switch dataMode {
        case .original: return originalRows
        case .transformed: return transformedRows
        }
    }
}
