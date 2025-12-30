import Foundation

protocol DataSource: Sendable {
    func preview(rows: Int) async throws -> ([Row], Schema)
    func stream(schema: Schema?) -> AsyncThrowingStream<DataChunk, Error>
}

extension DataSource {
    func stream() -> AsyncThrowingStream<DataChunk, Error> {
        stream(schema: nil)
    }
}


enum DataSourceError: Error {
    case fileNotFound
    case accessDenied
    case invalidFormat
    case emptyFile
}
