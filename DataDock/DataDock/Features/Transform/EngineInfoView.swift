import SwiftUI

struct EngineInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // CSV Stream Engine
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("CSV Stream Engine")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Text("Best for: Speed & Simplicity")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("The CSV Stream Engine processes data line-by-line, reading from the source file and writing directly to a destination CSV file.")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "Extremely fast for text-based operations")
                            BulletPoint(text: "Low memory usage (Streamed)")
                            BulletPoint(text: "Produces a standard CSV file ready for Excel/Numbers")
                            BulletPoint(text: "No database overhead")
                        }
                        .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // SQLite Engine
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cylinder.split.1x2.fill")
                                .font(.title)
                                .foregroundColor(.purple)
                            Text("SQLite Engine")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Text("Best for: Reliability & Complex Data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("The SQLite Engine loads data into a transactional SQL database file. This ensures data integrity and enables powerful querying capabilities.")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "ACID Transaction support (Safe & Reliable)")
                            BulletPoint(text: "Handles complex data types better")
                            BulletPoint(text: "Produces a .sqlite database file")
                            BulletPoint(text: "Great for massive datasets (Millions of rows)")
                        }
                        .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Engine Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("•")
                .fontWeight(.bold)
            Text(text)
        }
        .font(.callout)
    }
}
