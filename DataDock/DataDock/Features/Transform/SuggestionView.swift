import SwiftUI

struct SuggestionView: View {
    let profile: DatasetProfile
    let suggestions: [Suggestion]
    let onApply: (TransformOperation) -> Void
    @Environment(\.dismiss) var dismiss
    
    var aiSuggestions: [Suggestion] {
        suggestions.filter { $0.isAI }
    }
    
    var standardSuggestions: [Suggestion] {
        suggestions.filter { !$0.isAI }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dataset Analysis")
                            .font(.headline)
                        
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                            GridRow {
                                StatView(title: "Type", value: profile.datasetType.rawValue)
                                StatView(title: "Rows", value: "\(profile.rowCount)")
                            }
                            GridRow {
                                StatView(title: "Columns", value: "\(profile.columnProfiles.count)")
                                StatView(title: "Health", value: "Good") // Placeholder
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Profile")
                }
                
                // AI Suggestions Section
                if !aiSuggestions.isEmpty {
                    Section {
                        ForEach(aiSuggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion, onApply: onApply)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("AI Insights")
                        }
                        .foregroundColor(.purple)
                    }
                }
                
                // Standard Suggestions Section
                if !standardSuggestions.isEmpty {
                    Section {
                        ForEach(standardSuggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion, onApply: onApply)
                        }
                    } header: {
                        Text("Standard Recommendations")
                    }
                }
                
                if suggestions.isEmpty {
                    Section {
                        Text("No suggestions available.")
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Recommended Actions")
                    }
                }
                
                Section {
                    ForEach(profile.columnProfiles, id: \.columnName) { col in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(col.columnName)
                                    .font(.headline)
                                Spacer()
                                Text(col.type.rawValue)
                                    .font(.caption.bold())
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            HStack {
                                Text("\(Int(col.nullPercentage * 100))% Null")
                                Spacer()
                                Text("\(col.uniqueCount) Unique")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Column Details")
                }
            }
            .navigationTitle("Data Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct SuggestionRow: View {
    let suggestion: Suggestion
    let onApply: (TransformOperation) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(suggestion.title)
                        .font(.headline)
                    if suggestion.isAI {
                        Text("AI")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(8)
                    }
                }
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Apply") {
                onApply(suggestion.transform)
            }
            .buttonStyle(.bordered)
        }
    }
}
