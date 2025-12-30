import SwiftUI
import Charts

enum ChartType: String, CaseIterable, Identifiable {
    case bar
    case line
    case point
    case area
    case pie
    
    var id: String { rawValue }
}

struct DataChartView: View {
    let schema: Schema
    let rows: [Row]
    var minHeight: CGFloat = 300
    
    @Binding var selectedX: String
    @Binding var selectedY: String
    @Binding var chartType: ChartType
    
    @State private var selectedElement: String?
    @State private var labelAliases: [String: String] = [:]
    @State private var isEditingLabels = false
    
    // Initializer for when bindings are provided (e.g. Full Screen)
    init(schema: Schema, rows: [Row], minHeight: CGFloat = 300, selectedX: Binding<String>, selectedY: Binding<String>, chartType: Binding<ChartType>) {
        self.schema = schema
        self.rows = rows
        self.minHeight = minHeight
        self._selectedX = selectedX
        self._selectedY = selectedY
        self._chartType = chartType
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Configuration Controls
            VStack(spacing: 12) {
                Picker("Chart Type", selection: $chartType) {
                    ForEach(ChartType.allCases) { type in
                        Label(type.rawValue.capitalized, systemImage: icon(for: type))
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("X Axis (Category)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Menu {
                            Picker("X Axis", selection: $selectedX) {
                                Text("Select Column").tag("")
                                ForEach(schema.fields) { field in
                                    Text(field.name).tag(field.name)
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedX.isEmpty ? "Select..." : selectedX)
                                    .foregroundColor(selectedX.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        if !selectedX.isEmpty {
                            Button(action: { isEditingLabels.toggle() }) {
                                Label("Edit Labels", systemImage: "pencil.line")
                                    .font(.caption)
                            }
                            .popover(isPresented: $isEditingLabels) {
                                LabelEditorView(
                                    column: selectedX,
                                    values: uniqueValues(for: selectedX),
                                    aliases: $labelAliases
                                )
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Y Axis (Value)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Menu {
                            Picker("Y Axis", selection: $selectedY) {
                                Text("Select Column").tag("")
                                ForEach(numericFields) { field in
                                    Text(field.name).tag(field.name)
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedY.isEmpty ? "Select..." : selectedY)
                                    .foregroundColor(selectedY.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Chart Area
            if selectedX.isEmpty || selectedY.isEmpty {
                ContentUnavailableView(
                    "Select Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Choose columns for X and Y axes to generate the chart.")
                )
                .frame(minHeight: minHeight)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ZStack(alignment: .top) {
                    Chart {
                        ForEach(rows) { row in
                            if let rawX = value(for: selectedX, in: row),
                               let yVal = doubleValue(for: selectedY, in: row) {
                                
                                let xVal = labelAliases[rawX] ?? rawX
                                
                                switch chartType {
                                case .bar:
                                    BarMark(
                                        x: .value(selectedX, xVal),
                                        y: .value(selectedY, yVal)
                                    )
                                    .foregroundStyle(by: .value(selectedX, xVal))
                                    .opacity(selectedElement == nil || selectedElement == xVal ? 1 : 0.3)
                                    
                                case .line:
                                    LineMark(
                                        x: .value(selectedX, xVal),
                                        y: .value(selectedY, yVal)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .symbol(by: .value(selectedX, xVal))
                                    .opacity(selectedElement == nil || selectedElement == xVal ? 1 : 0.3)
                                    
                                case .point:
                                    PointMark(
                                        x: .value(selectedX, xVal),
                                        y: .value(selectedY, yVal)
                                    )
                                    .foregroundStyle(by: .value(selectedX, xVal))
                                    .opacity(selectedElement == nil || selectedElement == xVal ? 1 : 0.3)
                                    
                                case .area:
                                    AreaMark(
                                        x: .value(selectedX, xVal),
                                        y: .value(selectedY, yVal)
                                    )
                                    .foregroundStyle(LinearGradient(
                                        colors: [.blue.opacity(0.6), .blue.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .opacity(selectedElement == nil || selectedElement == xVal ? 1 : 0.3)
                                    
                                case .pie:
                                    SectorMark(
                                        angle: .value(selectedY, yVal),
                                        innerRadius: .ratio(0.5),
                                        angularInset: 1.5
                                    )
                                    .foregroundStyle(by: .value(selectedX, xVal))
                                    .opacity(selectedElement == nil || selectedElement == xVal ? 1 : 0.3)
                                }
                            }
                        }
                        
                        if let selected = selectedElement {
                            RuleMark(x: .value(selectedX, selected))
                                .foregroundStyle(.gray.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                .annotation(position: .top) {
                                    TooltipView(
                                        title: selected,
                                        value: calculateAggregate(for: selected),
                                        label: selectedY
                                    )
                                }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let location = value.location
                                            if let category: String = proxy.value(atX: location.x) {
                                                selectedElement = category
                                            }
                                        }
                                        .onEnded { _ in
                                            selectedElement = nil
                                        }
                                )
                        }
                    }
                    .chartLegend(position: .bottom)
                    .frame(minHeight: minHeight)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .onAppear {
            updateSelectionIfNeeded()
        }
        .onChange(of: schema.fields.map { $0.name }) { _ in
            updateSelectionIfNeeded()
        }
    }
    
    private func updateSelectionIfNeeded() {
        // If current selection is invalid for new schema, reset
        if !schema.fields.contains(where: { $0.name == selectedX }) {
            selectedX = schema.fields.first?.name ?? ""
        }
        if !numericFields.contains(where: { $0.name == selectedY }) {
            selectedY = numericFields.first?.name ?? ""
        }
    }
    
    private var numericFields: [Schema.Field] {
        schema.fields.filter { $0.type == .integer || $0.type == .double }
    }
    
    private func icon(for type: ChartType) -> String {
        switch type {
        case .bar: return "chart.bar.fill"
        case .line: return "chart.line.uptrend.xyaxis"
        case .point: return "circle.grid.cross.fill"
        case .area: return "chart.area.fill"
        case .pie: return "chart.pie.fill"
        }
    }
    
    private func value(for column: String, in row: Row) -> String? {
        guard let index = schema.index(of: column),
              let val = row[index] else { return nil }
        return val.description
    }
    
    private func doubleValue(for column: String, in row: Row) -> Double? {
        guard let index = schema.index(of: column),
              let val = row[index] else { return nil }
        
        switch val {
        case .integer(let i): return Double(i)
        case .double(let d): return d
        case .string(let s): return Double(s)
        default: return nil
        }
    }
    
    private func uniqueValues(for column: String) -> [String] {
        guard let index = schema.index(of: column) else { return [] }
        let values = rows.compactMap { $0[index]?.description }
        return Array(Set(values)).sorted()
    }
    
    private func calculateAggregate(for category: String) -> String {
        guard let yIndex = schema.index(of: selectedY),
              let xIndex = schema.index(of: selectedX) else { return "-" }
        
        var sum: Double = 0
        var count: Int = 0
        
        for row in rows {
            if let xVal = row[xIndex] {
                // Check against raw value OR aliased value
                let raw = xVal.description
                let alias = labelAliases[raw] ?? raw
                
                if alias == category {
                    let doubleVal: Double
                    // ... (rest of calculation)
                    if let yVal = row[yIndex] {
                         switch yVal {
                         case .integer(let i): doubleVal = Double(i)
                         case .double(let d): doubleVal = d
                         case .string(let s): doubleVal = Double(s) ?? 0
                         default: doubleVal = 0
                         }
                         sum += doubleVal
                         count += 1
                    }
                }
            }
        }
        
        // Simple formatting
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let sumStr = formatter.string(from: NSNumber(value: sum)) ?? "-"
        
        return "Total: \(sumStr)"
    }
}

struct LabelEditorView: View {
    let column: String
    let values: [String]
    @Binding var aliases: [String: String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Rename standard values (e.g., '0' -> 'Female') to make the chart easier to understand. This only affects the visual chart, not your data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
                
                ForEach(values, id: \.self) { value in
                    HStack {
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.gray) // Fixed deprecated/invalid usage
                        
                        TextField("Alias", text: Binding(
                            get: { aliases[value] ?? "" },
                            set: { aliases[value] = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .navigationTitle("Edit Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}

struct TooltipView: View {
    let title: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.primary)
            Text(value)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}
