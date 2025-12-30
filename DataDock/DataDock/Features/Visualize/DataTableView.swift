import SwiftUI

struct DataTableView: View {
    let schema: Schema
    let rows: [Row]
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(schema.fields) { field in
                        Text(field.name)
                            .font(.headline)
                            .frame(width: 150, alignment: .leading)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .border(Color.gray.opacity(0.3))
                    }
                }
                
                // Rows
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<schema.fields.count, id: \.self) { index in
                            Text(row[index]?.description.prefix(50) ?? "")
                                .lineLimit(1)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 150, alignment: .leading)
                                .padding(8)
                                .border(Color.gray.opacity(0.1))
                        }
                    }
                }
            }
        }
    }
}
