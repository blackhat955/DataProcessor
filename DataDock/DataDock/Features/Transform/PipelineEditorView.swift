import SwiftUI
import UniformTypeIdentifiers

struct TransformWrapper: Identifiable {
    let id: UUID
    let operation: TransformOperation
    
    init(_ operation: TransformOperation) {
        self.id = operation.id
        self.operation = operation
    }
}

struct PipelineEditorView: View {
    let fileURL: URL
    let schema: Schema
    
    @State private var transforms: [TransformWrapper] = []
    @State private var pipeline = PipelineEngine()
    @State private var isExporting = false
    @State private var tempResultURL: URL?
    
    // Preview State
    @State private var rawRows: [Row] = []
    @State private var previewRows: [Row] = []
    @State private var initialSchema: Schema? // Schema matching rawRows
    @State private var previewSchema: Schema? // Schema matching previewRows
    @State private var isPreviewLoading = true
    @State private var viewMode: ViewMode = .table
    @State private var previewSource: PreviewSource = .transformed
    @State private var isFullScreenChartPresented = false
    
    // Preview Chart State
    @State private var previewSelectedX: String = ""
    @State private var previewSelectedY: String = ""
    @State private var previewChartType: ChartType = .bar
    
    @State private var profile: DatasetProfile?
    @State private var suggestions: [Suggestion] = []
    @State private var showSuggestions = false
    
    // Output Format
    @State private var useSQLite = false
    @State private var showEngineInfo = false
    
    enum ViewMode {
        case table
        case chart
    }
    
    enum PreviewSource {
        case original
        case transformed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            configArea
            Divider()
            previewArea
            actionBar
        }
        .navigationTitle("Pipeline")
        .task {
            await loadInitialPreview()
        }
        .onChange(of: transforms.map { $0.id }) { _ in
            // Auto-switch to transformed view when a transform is added/removed
            if !transforms.isEmpty {
                previewSource = .transformed
            }
            Task { await updatePreview() }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: CSVFile(initialText: "", fileURL: tempResultURL),
            contentTypes: useSQLite ? [.database] : [.commaSeparatedText, .json],
            defaultFilename: "ExportedData"
        ) { result in
            switch result {
            case .success(let url):
                saveExport(to: url)
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var configArea: some View {
        List {
            // Data Profile Section
            Section {
                if let profile = profile {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.blue)
                            Text("Data Profile")
                                .font(.headline)
                            Spacer()
                            Text(profile.datasetType.rawValue)
                                .font(.caption)
                                .padding(4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Text("Analyzed \(profile.rowCount) rows. Found \(profile.columnProfiles.count) columns.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !suggestions.isEmpty {
                            let aiCount = suggestions.filter { $0.isAI }.count
                            Button(action: { showSuggestions = true }) {
                                HStack {
                                    if aiCount > 0 {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.purple)
                                        Text("View \(suggestions.count) Suggestions (\(aiCount) AI)")
                                            .foregroundColor(.purple)
                                            .fontWeight(.medium)
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("View \(suggestions.count) Suggestions")
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Analyzing data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Source Data")
            }
            
            Section {
                if transforms.isEmpty {
                    ContentUnavailableView(
                        "No Transforms",
                        systemImage: "slider.horizontal.3",
                        description: Text("Add steps to transform your data.")
                    )
                    .listRowBackground(Color.clear)
                    .frame(height: 100)
                }
                
                ForEach(Array(transforms.enumerated()), id: \.element.id) { index, wrapper in
                    HStack(spacing: 12) {
                        // Step Number
                        ZStack {
                            Circle()
                                .fill(color(for: wrapper.operation.type).opacity(0.2))
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(color(for: wrapper.operation.type))
                        }
                        
                        // Icon
                        Image(systemName: icon(for: wrapper.operation.type))
                            .foregroundColor(color(for: wrapper.operation.type))
                            .font(.title3)
                            .frame(width: 30)
                        
                        // Content
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wrapper.operation.type.rawValue.capitalized)
                                .font(.subheadline.bold())
                            
                            if let filter = wrapper.operation as? FilterTransform {
                                Text("\(filter.condition.column) \(filter.condition.op.rawValue) \(filter.condition.value)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let sort = wrapper.operation as? SortTransform {
                                Text("Sort by \(sort.column) (\(sort.order.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let select = wrapper.operation as? SelectTransform {
                                Text("Keep \(select.columns.count) columns")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let text = wrapper.operation as? TextTransform {
                                Text("\(text.operation.rawValue.capitalized) \(text.column)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let math = wrapper.operation as? MathTransform {
                                Text("\(math.column) \(math.operation.rawValue) \(String(format: "%.1f", math.value))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let findReplace = wrapper.operation as? FindReplaceTransform {
                                Text("Replace '\(findReplace.findText)' with '\(findReplace.replaceText)' in \(findReplace.column)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            if let idx = transforms.firstIndex(where: { $0.id == wrapper.id }) {
                                transforms.remove(at: idx)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                Button("Find & Replace") {
                    if let field = schema.fields.first(where: { $0.type == .string }) {
                        // Demo: Replace '?' with 'Unknown'
                        let findReplace = FindReplaceTransform(column: field.name, findText: "?", replaceText: "Unknown", isCaseSensitive: false)
                        transforms.append(TransformWrapper(findReplace))
                    }
                }
            } header: {
                Text("Transforms Pipeline")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Engine Selection", systemImage: "cpu")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { showEngineInfo = true }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Picker("Engine", selection: $useSQLite) {
                        Text("CSV Stream").tag(false)
                        Text("SQLite Engine").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if useSQLite {
                        HStack(spacing: 8) {
                            Image(systemName: "cylinder.split.1x2.fill")
                                .foregroundColor(.purple)
                            Text("Using Transactional Database")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.green)
                            Text("Using Fast Text Streaming")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(spacing: 16) {
                    // Header Status
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            switch pipeline.status {
                            case .idle:
                                Label("Ready", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.headline)
                            case .running:
                                Label("Running...", systemImage: "gearshape.2.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                    .symbolEffect(.variableColor.iterative.reversing)
                            case .completed:
                                Label("Completed", systemImage: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.headline)
                            case .failed(let error):
                                Label("Failed", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.headline)
                            case .cancelled:
                                Label("Cancelled", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        if case .failed(let error) = pipeline.status {
                             Text(error)
                                 .font(.caption2)
                                 .foregroundColor(.red)
                                 .multilineTextAlignment(.trailing)
                                 .frame(maxWidth: 150)
                        }
                    }
                    
                    // Progress Bar Area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Processed Rows")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(pipeline.processedRows)")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                        }
                        
                        if pipeline.status == .running {
                            ProgressView()
                                .progressViewStyle(.linear)
                                .tint(.blue)
                        } else if pipeline.status == .completed {
                            ProgressView(value: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.green)
                        } else {
                            ProgressView(value: 0.0)
                                .progressViewStyle(.linear)
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Execution")
            }
        }
        .listStyle(.insetGrouped)
        .frame(height: 380) // Increased height for new UI
        .sheet(isPresented: $showEngineInfo) {
            EngineInfoView()
        }
        .sheet(isPresented: $showSuggestions) {
            if let profile = profile {
                SuggestionView(profile: profile, suggestions: suggestions) { transform in
                    transforms.append(TransformWrapper(transform))
                    showSuggestions = false
                }
            }
        }
    }
    
    private var previewArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Live Preview")
                    .font(.headline)
                
                Spacer()
                
                Picker("Source", selection: $previewSource) {
                    Text("Original").tag(PreviewSource.original)
                    Text("Transformed").tag(PreviewSource.transformed)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .padding(.trailing, 8)
                
                Picker("View Mode", selection: $viewMode) {
                    Image(systemName: "tablecells").tag(ViewMode.table)
                    Image(systemName: "chart.bar").tag(ViewMode.chart)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            if isPreviewLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let (currentRows, currentSchema) = activePreviewData
                
                if let s = currentSchema {
                    switch viewMode {
                    case .table:
                        DataTableView(schema: s, rows: currentRows)
                    case .chart:
                        ZStack(alignment: .topTrailing) {
                            ScrollView {
                                DataChartView(
                                    schema: s,
                                    rows: currentRows,
                                    selectedX: $previewSelectedX,
                                    selectedY: $previewSelectedY,
                                    chartType: $previewChartType
                                )
                                .padding(.top)
                            }
                            
                            Button(action: { isFullScreenChartPresented = true }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                        .sheet(isPresented: $isFullScreenChartPresented) {
                            NavigationStack {
                                VisualizationDetailView(
                                    originalSchema: schema,
                                    originalRows: rawRows,
                                    transformedSchema: s,
                                    transformedRows: currentRows
                                )
                                    .toolbar {
                                        ToolbarItem(placement: .cancellationAction) {
                                            Button("Close") {
                                                isFullScreenChartPresented = false
                                            }
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    Text("No Preview Available")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var actionBar: some View {
        HStack {
            Menu("Add Transform") {
                Button("Filter Rows") {
                    if let firstField = schema.fields.first {
                        let filter = FilterTransform(condition: FilterCondition(column: firstField.name, op: .notEquals, value: ""))
                        transforms.append(TransformWrapper(filter))
                    }
                }
                Button("Select All Columns") {
                     let select = SelectTransform(columns: schema.fields.map { $0.name })
                     transforms.append(TransformWrapper(select))
                }
                Button("Sort Ascending") {
                    if let firstField = schema.fields.first {
                        let sort = SortTransform(column: firstField.name, order: .ascending)
                        transforms.append(TransformWrapper(sort))
                    }
                }
                Button("Sort Descending") {
                    if let firstField = schema.fields.first {
                        let sort = SortTransform(column: firstField.name, order: .descending)
                        transforms.append(TransformWrapper(sort))
                    }
                }
                
                Divider()
                
                Menu("Text Operations") {
                    Button("Uppercase") {
                        if let field = schema.fields.first(where: { $0.type == .string }) {
                            let text = TextTransform(column: field.name, operation: .uppercase)
                            transforms.append(TransformWrapper(text))
                        }
                    }
                    Button("Lowercase") {
                        if let field = schema.fields.first(where: { $0.type == .string }) {
                            let text = TextTransform(column: field.name, operation: .lowercase)
                            transforms.append(TransformWrapper(text))
                        }
                    }
                }
                
                Menu("Math Operations") {
                    Button("Add 10") {
                        if let field = schema.fields.first(where: { $0.type == .integer || $0.type == .double }) {
                            let math = MathTransform(column: field.name, operation: .add, value: 10)
                            transforms.append(TransformWrapper(math))
                        }
                    }
                    Button("Multiply by 2") {
                        if let field = schema.fields.first(where: { $0.type == .integer || $0.type == .double }) {
                            let math = MathTransform(column: field.name, operation: .multiply, value: 2)
                            transforms.append(TransformWrapper(math))
                        }
                    }
                    Button("Square (Power 2)") {
                        if let field = schema.fields.first(where: { $0.type == .integer || $0.type == .double }) {
                            let math = MathTransform(column: field.name, operation: .power, value: 2)
                            transforms.append(TransformWrapper(math))
                        }
                    }
                    Button("Round") {
                        if let field = schema.fields.first(where: { $0.type == .double }) {
                            let math = MathTransform(column: field.name, operation: .round, value: 0)
                            transforms.append(TransformWrapper(math))
                        }
                    }
                }
                
                Divider()
                
                Button("Find & Replace") {
                    if let field = schema.fields.first(where: { $0.type == .string }) {
                        // Demo: Replace '?' with 'Unknown'
                        let findReplace = FindReplaceTransform(column: field.name, findText: "?", replaceText: "Unknown", isCaseSensitive: false)
                        transforms.append(TransformWrapper(findReplace))
                    }
                }
            }
            
            Spacer()
            
            if pipeline.status == .running {
                Button("Cancel") {
                    pipeline.cancel()
                }
                .tint(.red)
            } else if pipeline.status == .completed {
                 HStack {
                     Button("Run Again") {
                         startPipeline()
                     }
                     .buttonStyle(.bordered)
                     
                     Button("Export Result") {
                         isExporting = true
                     }
                     .buttonStyle(.borderedProminent)
                 }
            } else {
                Button("Run Pipeline") {
                    startPipeline()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    var activePreviewData: ([Row], Schema?) {
        switch previewSource {
        case .original:
            return (rawRows, initialSchema ?? schema)
        case .transformed:
            return (previewRows, previewSchema)
        }
    }
    
    func loadInitialPreview() async {
        let isNetwork = fileURL.scheme?.hasPrefix("http") == true
        if !isNetwork {
            guard fileURL.startAccessingSecurityScopedResource() else { return }
        }
        defer { 
            if !isNetwork { fileURL.stopAccessingSecurityScopedResource() }
        }
        
        do {
            let extractor: DataSource
            if isNetwork {
                 if fileURL.pathExtension.contains("json") {
                     extractor = JSONExtractor(url: fileURL)
                 } else {
                     extractor = NetworkExtractor(url: fileURL)
                 }
            } else {
                 if fileURL.pathExtension.contains("json") {
                     extractor = JSONExtractor(url: fileURL)
                 } else {
                     extractor = CSVExtractor(url: fileURL)
                 }
            }
            
            // Use stream to get preview rows respecting the defined schema
            var rows: [Row] = []
            for try await chunk in extractor.stream(schema: schema) {
                rows.append(contentsOf: chunk.rows)
                if rows.count >= 50 { break }
            }
            rows = Array(rows.prefix(50))
            
            // Profiling
            let profiler = DataProfiler()
            let chunk = DataChunk(id: UUID(), rows: rows, schema: schema)
            let datasetProfile = await profiler.profile(chunk: chunk)
            var inferredSuggestions = TransformationSuggester.suggest(from: datasetProfile)
            
            // AI Analysis
            let aiSuggester = SmartSuggester()
            let aiResults = await aiSuggester.analyze(profile: datasetProfile, sampleRows: rows)
            
            for ai in aiResults {
                // Map AI result to concrete transform suggestion
                switch ai.type {
                case .sentiment:
                     // Maybe suggest filtering out negative sentiment?
                     // For now, just suggest "Uppercase" as a placeholder for "Text Analysis"
                     let text = TextTransform(column: ai.columnName, operation: .uppercase)
                     inferredSuggestions.append(Suggestion(
                        title: "Analyze Sentiment: \(ai.columnName)",
                        description: "AI detected sentiment-rich text (Confidence: \(Int(ai.confidence * 100))%)",
                        transform: text,
                        isAI: true
                     ))
                case .entityRecognition:
                     let text = TextTransform(column: ai.columnName, operation: .capitalize)
                     inferredSuggestions.append(Suggestion(
                        title: "Extract Entities: \(ai.columnName)",
                        description: ai.reason,
                        transform: text,
                        isAI: true
                     ))
                case .languageIdentification:
                     break
                case .smartClassification:
                     // For categorical numbers, suggest sorting to group them
                     let sort = SortTransform(column: ai.columnName, order: .ascending)
                     inferredSuggestions.append(Suggestion(
                        title: "Group Categories: \(ai.columnName)",
                        description: ai.reason,
                        transform: sort,
                        isAI: true
                     ))
                default: break
                }
            }
            
            let finalSuggestions = inferredSuggestions
            
            await MainActor.run {
                self.rawRows = rows
                self.previewRows = rows
                self.initialSchema = schema // Now matches defined schema
                self.previewSchema = schema 
                self.profile = datasetProfile
                self.suggestions = finalSuggestions
                self.isPreviewLoading = false
                if !finalSuggestions.isEmpty {
                    self.showSuggestions = true
                }
            }
        } catch {
            print("Failed to load preview: \(error)")
            await MainActor.run { isPreviewLoading = false }
        }
    }
    
    func updatePreview() async {
        guard !rawRows.isEmpty, let initialS = initialSchema else { return }
        
        // Start with raw data
        var currentChunk = DataChunk(id: UUID(), rows: rawRows, schema: initialS)
        
        do {
            for wrapper in transforms {
                currentChunk = try await wrapper.operation.apply(to: currentChunk)
            }
            
            let resultChunk = currentChunk
            await MainActor.run {
                self.previewRows = resultChunk.rows
                self.previewSchema = resultChunk.schema
            }
        } catch {
            print("Preview update failed: \(error)")
        }
    }
    
    func startPipeline() {
        // Create a temporary URL for the result
        let tempDir = FileManager.default.temporaryDirectory
        
        let fileName = UUID().uuidString + (useSQLite ? ".sqlite" : ".csv")
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        self.tempResultURL = tempURL
        
        let isNetwork = fileURL.scheme?.hasPrefix("http") == true
        
        let extractor: DataSource
        if isNetwork {
            // Check extension for JSON
            if fileURL.pathExtension.contains("json") {
                extractor = JSONExtractor(url: fileURL)
            } else {
                extractor = NetworkExtractor(url: fileURL)
            }
        } else {
            if fileURL.pathExtension.contains("json") {
                extractor = JSONExtractor(url: fileURL)
            } else {
                extractor = CSVExtractor(url: fileURL)
            }
        }
        
        let loader: Loader
        if useSQLite {
            loader = SQLiteLoader(dbPath: tempURL.path)
        } else {
            loader = CSVLoader(url: tempURL)
        }
        
        let operations = transforms.map { $0.operation }
        
        // Use the refined initial schema if available, otherwise fallback to the passed schema
        let sourceSchema = initialSchema ?? schema
        
        pipeline.start(extractor: extractor, schema: sourceSchema, transforms: operations, loader: loader)
    }
    
    func saveExport(to outputURL: URL) {
        guard let sourceURL = tempResultURL else { return }
        guard outputURL.startAccessingSecurityScopedResource() else { return }
        defer { outputURL.stopAccessingSecurityScopedResource() }
        
        let isJSON = outputURL.pathExtension.lowercased().contains("json")
        let isSQLite = outputURL.pathExtension.lowercased().contains("sqlite") || outputURL.pathExtension.lowercased().contains("db")
        
        if isJSON {
            // Convert CSV to JSON
            // If source is already SQLite, we might need a SQLiteExtractor (future)
            // For now, assuming source matches current pipeline config which matches tempURL extension
            
            // Check source format
            if sourceURL.pathExtension.contains("sqlite") {
                // TODO: Implement SQLite -> JSON conversion if needed
                // For now, just copy if user messed up extensions, or fail
                print("Conversion from SQLite to JSON not yet implemented in export")
            } else {
                 Task {
                     let extractor = CSVExtractor(url: sourceURL) // Temp is always CSV
                     let loader = JSONLoader(url: outputURL, isPretty: true)
                     
                     // Simple pass-through pipeline
                     let engine = PipelineEngine()
                     await engine.start(extractor: extractor, schema: schema, transforms: [], loader: loader)
                 }
            }
        } else {
            // Just copy
            do {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: outputURL)
            } catch {
                print("Failed to copy export file: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func icon(for type: TransformType) -> String {
        switch type {
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        case .select: return "checkmark.rectangle.stack.fill"
        case .rename: return "pencil.and.scribble"
        case .sort: return "arrow.up.arrow.down.square.fill"
        case .text: return "textformat.abc"
        case .math: return "function"
        case .findReplace: return "magnifyingglass"
        }
    }
    
    private func color(for type: TransformType) -> Color {
        switch type {
        case .filter: return .blue
        case .select: return .green
        case .rename: return .orange
        case .sort: return .purple
        case .text: return .indigo
        case .math: return .pink
        case .findReplace: return .cyan
        }
    }
}

struct CSVFile: FileDocument {
    static var readableContentTypes = [UTType.commaSeparatedText, UTType.json, UTType.plainText, UTType.database]
    var text = ""
    var fileURL: URL?

    init(initialText: String = "", fileURL: URL? = nil) {
        self.text = initialText
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if let url = fileURL {
            return try FileWrapper(url: url, options: .immediate)
        }
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
