import Foundation
import Core

/// A codable snapshot of a story's state at a moment in time.
public struct StorySave<State: StoryState & Codable & Sendable>: Codable, Sendable {
    /// An application-meaningful identifier of the story.
    public var storyID: String
    /// The captured application-defined state.
    public var state: State
    /// The time the snapshot was created.
    public var timestamp: Date
    public init(storyID: String, state: State, timestamp: Date = .init()) {
        self.storyID = storyID
        self.state = state
        self.timestamp = timestamp
    }
}

/// A provider capable of saving and loading story state snapshots.
public protocol SaveProvider<State>: Sendable {
    associatedtype State: StoryState & Codable & Sendable
    /// Saves a snapshot to a named slot.
    func save(slot: String, snapshot: StorySave<State>) async throws
    /// Loads a snapshot from a named slot, or `nil` if missing.
    func load(slot: String) async throws -> StorySave<State>?
    /// Lists available slots.
    func listSlots() async -> [String]
}

/// An in-memory snapshot provider useful for tests and previews.
public actor InMemorySaveProvider<State: StoryState & Codable & Sendable>: SaveProvider {
    private var storage: [String: Data] = [:]

    public init() {}

    public func save(slot: String, snapshot: StorySave<State>) async throws {
        let data = try JSONEncoder().encode(snapshot)
        storage[slot] = data
    }

    public func load(slot: String) async throws -> StorySave<State>? {
        guard let data = storage[slot] else { return nil }
        return try JSONDecoder().decode(StorySave<State>.self, from: data)
    }

    public func listSlots() async -> [String] {
        Array(storage.keys).sorted()
    }
}

/// A JSON file-based snapshot provider that persists each slot to a `.json` file.
public actor JSONFileSaveProvider<State: StoryState & Codable & Sendable>: SaveProvider {
    private let directory: URL
    /// Creates a file-backed provider writing into the given directory.
    public init(directory: URL) {
        self.directory = directory
    }

    private func url(for slot: String) -> URL {
        directory.appendingPathComponent("\(slot).json")
    }

    public func save(slot: String, snapshot: StorySave<State>) async throws {
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url(for: slot), options: .atomic)
    }

    public func load(slot: String) async throws -> StorySave<State>? {
        let url = url(for: slot)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StorySave<State>.self, from: data)
    }

    public func listSlots() async -> [String] {
        guard let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return items.filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}

// MARK: - Autosave helpers

/// Constructs an autosave handler that saves to a given slot whenever called.
public func makeAutoSaveHandler<State, Provider: SaveProvider>(
    storyID: String,
    slot: String,
    provider: Provider
) -> @Sendable (State) async throws -> Void where Provider.State == State {
    return { state in
        let snapshot = StorySave<State>(storyID: storyID, state: state)
        try await provider.save(slot: slot, snapshot: snapshot)
    }
}
