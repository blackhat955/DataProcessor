# DataDock ETL Engine Architecture

##  Architecture Overview

DataDock implements a **Streaming ETL Engine** designed for iOS. It prioritizes memory safety and offline capability by processing data in chunks rather than loading entire datasets into RAM.

```ascii
+----------------+      +------------------+      +----------------+
|                |      |                  |      |                |
|  Extract (E)   | ---> |  Transform (T)   | ---> |    Load (L)    |
|                |      |                  |      |                |
+----------------+      +------------------+      +----------------+
| CSVExtractor   |      | FilterTransform  |      | CSVLoader      |
| JSONExtractor  |      | MathTransform    |      | SQLiteLoader   |
| NetworkSource  |      | SortTransform    |      | JSONLoader     |
+-------+--------+      +--------+---------+      +-------+--------+
        |                        |                        |
        v                        v                        v
  AsyncStream<Chunk>     AsyncStream<Chunk>       Write Batch
```

---

##  Folder Structure

The codebase is organized by functional layers to ensure separation of concerns:

```
DataDock/
├── Core/
│   ├── Engine/
│   │   ├── PipelineEngine.swift  # Orchestrator (State Machine)
│   │   ├── DataSource.swift      # Extractor Protocol
│   │   ├── Transform.swift       # Transform Protocol & Implementations
│   │   └── Loader.swift          # Loader Protocol
│   └── Models/
│       └── DataModels.swift      # Schema, Row, DataChunk
├── Services/
│   ├── FileIO/
│   │   ├── CSVExtractor.swift
│   │   ├── JSONExtractor.swift
│   │   ├── NetworkExtractor.swift
│   │   ├── CSVLoader.swift
│   │   └── JSONLoader.swift
│   └── Database/
│       ├── SQLiteDatabase.swift  # Low-level SQLite Wrapper
│       └── SQLiteLoader.swift    # Batch Loader
└── Features/
    ├── Import/                   # UI for selecting data
    ├── Transform/                # UI for building pipeline
    └── Visualize/                # UI for charts
```

---

## 🔑 Core Protocols

### 1. Extractor (`DataSource`)
Designed for **Incremental Reads**. It emits an async stream of `DataChunks' to keep memory footprint low (O(1) space complexity relative to file size).

```swift
protocol DataSource: Sendable {
    func preview(rows: Int) async throws -> ([Row], Schema)
    func stream(schema: Schema?) -> AsyncThrowingStream<DataChunk, Error>
}
```

### 2. Transform (`TransformOperation`)
Designed to be **Pluggable & Stateless**. Transforms are applied sequentially to each chunk.

```swift
protocol TransformOperation: Sendable {
    var id: UUID { get }
    var type: TransformType { get }
    func apply(to chunk: DataChunk) async throws -> DataChunk
}
```

### 3. Loader (`Loader`)
Designed for **Batch Persistence**. It handles opening resources, writing chunks transactionally, and closing safely.

```swift
protocol Loader: Sendable {
    func prepare() async throws
    func write(chunk: DataChunk) async throws
    func finish() async throws
}
```

---

##  Key Design Decisions

### 1. Streaming vs. In-Memory
**Decision:** We chose a **Streaming** architecture using Swift's `AsyncThrowingStream`.
**Why:** iOS devices have strict memory limits. Loading a 500MB CSV into memory would crash the app. Streaming processes 1,000 rows at a time, keeping RAM usage constant (~5MB) regardless of input size.

### 2. SQLite for Local Storage
**Decision:** Used `sqlite3` C API directly (via a lightweight wrapper).
**Why:** SQLite is built into iOS, requires no external dependencies (keeping the binary small), and is ACID-compliant. We use **transactions per batch** to balance performance with resumability.

### 3. Actor-Based Concurrency
**Decision:** All Extractors and Loaders are `actors`.
**Why:** This guarantees thread safety when accessing file handles or database connections. Swift's `actor` model prevents race conditions without manual locking.

### 4. Pluggable Transforms
**Decision:** Transforms conform to a simple protocol.
**Why:** This allows the UI to dynamically build a pipeline. Users can add, remove, or reorder steps (e.g., Filter -> Sort -> Math) without changing the engine code.

---

##  Error Handling & Resilience

1.  **Cancellation**: The `PipelineEngine` checks `Task.isCancelled` between chunks. This allows users to stop long-running jobs instantly.
2.  **Memory Pressure**: By using small chunk sizes (default 1,000 rows), we avoid system jetsam events.
3.  **Bad Rows**: The Extractors currently skip or nullify malformed rows to prevent the entire pipeline from failing (Best Effort).
4.  **Transactions**: The `SQLiteLoader` wraps writes in transactions. If a write fails, the database remains in a consistent state.

---

##  Performance Considerations

*   **Batching**: Writing to SQLite one row at a time is slow (1000s of fsyncs). We batch writes (1,000 rows per transaction), speeding up inserts by ~100x.
*   **Indexing**: For this ETL phase, we focus on write speed (INSERTs). Indexes should be created *after* the load is complete to avoid re-indexing overhead during insertion.
*   **Concurrency**: The pipeline runs on a detached `Task` with `userInitiated` priority, keeping the main thread free for UI updates (Progress Bar, Cancel Button).
