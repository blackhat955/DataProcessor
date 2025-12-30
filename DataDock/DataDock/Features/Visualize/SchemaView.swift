import SwiftUI

struct SchemaView: View {
    let schema: Schema
    
    var body: some View {
        List(schema.fields) { field in
            HStack {
                Text(field.name)
                    .font(.headline)
                Spacer()
                Text(field.type.rawValue.capitalized)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .navigationTitle("Schema")
    }
}
