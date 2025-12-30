import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var isImporting = false
    @State private var isEnteringURL = false
    @State private var urlString = ""
    @State private var importedFile: URL?
    @State private var previewRows: [Row] = []
    @State private var schema: Schema?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if let schema = schema, !previewRows.isEmpty, let fileURL = importedFile {
                VStack(spacing: 0) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: fileURL.isFileURL ? "doc.text.fill" : "network")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileURL.lastPathComponent)
                                    .font(.headline)
                                Text("CSV Source • \(previewRows.count) Rows Preview")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Menu("Change Source") {
                                Button("Select File") {
                                    isImporting = true
                                }
                                Button("Enter URL") {
                                    urlString = ""
                                    isEnteringURL = true
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        Divider()
                        
                        NavigationLink("Start Transformation Pipeline") {
                            PipelineEditorView(fileURL: fileURL, schema: schema)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .controlSize(.large)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()
                    
                    // Preview Table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Preview")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        DataTableView(schema: schema, rows: previewRows)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Import Data", systemImage: "arrow.down.doc.fill")
                } description: {
                    Text("Select a CSV file or enter a URL to begin your ETL process.")
                } actions: {
                    VStack(spacing: 12) {
                        Button("Select Local File") {
                            isImporting = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Import from URL") {
                            urlString = ""
                            isEnteringURL = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText, .plainText, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFile(url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isEnteringURL) {
            VStack(spacing: 24) {
                Text("Import from URL")
                    .font(.headline)
                
                TextField("https://example.com/data.csv", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isEnteringURL = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import") {
                        if let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                            importFile(url)
                            isEnteringURL = false
                        } else {
                            errorMessage = "Please enter a valid HTTP/HTTPS URL."
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlString.isEmpty)
                }
            }
            .padding()
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .navigationTitle("DataDock")
    }
    
    func importFile(_ url: URL) {
        let isNetwork = url.scheme?.hasPrefix("http") == true
        
        if !isNetwork {
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Permission denied"
                return
            }
        }
        
        importedFile = url
        errorMessage = nil // Clear errors
        
        Task {
            do {
                let extractor: DataSource = isNetwork ? NetworkExtractor(url: url) : CSVExtractor(url: url)
                let (rows, schema) = try await extractor.preview(rows: 20)
                await MainActor.run {
                    self.previewRows = rows
                    self.schema = schema
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
