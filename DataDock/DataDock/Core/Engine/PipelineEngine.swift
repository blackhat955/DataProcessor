import Foundation
import Observation

enum PipelineStatus: Equatable {
    case idle
    case running
    case completed
    case failed(String)
    case cancelled
}

@Observable
class PipelineEngine: @unchecked Sendable {
    var status: PipelineStatus = .idle
    var processedRows: Int = 0
    var errorMessage: String?
    
    private var currentTask: Task<Void, Never>?
    
    @MainActor
    func start(extractor: DataSource, schema: Schema? = nil, transforms: [TransformOperation], loader: Loader) {
        guard status != .running else { return }
        
        status = .running
        processedRows = 0
        errorMessage = nil
        
        currentTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            do {
                try await loader.prepare()
                
                for try await chunk in extractor.stream(schema: schema) {
                    if Task.isCancelled { break }
                    
                    var processedChunk = chunk
                    
                    // Apply transforms sequentially
                    for transform in transforms {
                        processedChunk = try await transform.apply(to: processedChunk)
                    }
                    
                    // Load
                    try await loader.write(chunk: processedChunk)
                    
                    await self.incrementProgress(count: processedChunk.rows.count)
                }
                
                try await loader.finish()
                
                await self.finalize(cancelled: Task.isCancelled)
            } catch {
                await self.fail(error: error)
            }
        }
    }
    
    @MainActor
    func cancel() {
        currentTask?.cancel()
        status = .cancelled
    }
    
    @MainActor
    private func incrementProgress(count: Int) {
        processedRows += count
    }
    
    @MainActor
    private func finalize(cancelled: Bool) {
        if cancelled {
            status = .cancelled
        } else {
            status = .completed
        }
    }
    
    @MainActor
    private func fail(error: Error) {
        errorMessage = error.localizedDescription
        status = .failed(error.localizedDescription)
    }
}
