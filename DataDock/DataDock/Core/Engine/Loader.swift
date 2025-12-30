import Foundation

protocol Loader: Sendable {
    func prepare() async throws
    func write(chunk: DataChunk) async throws
    func finish() async throws
}
