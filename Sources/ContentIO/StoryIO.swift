import Foundation
import Core
import CryptoKit
import Dispatch

/// Errors thrown while loading Markdown text or locating sections.
public enum StoryIOError: Error, Equatable {
    case invalidPath
    case decodeFailed
    case textSectionMissing(TextRef)
}

/// Describes the on-disk layout for a human-authored story source.
public struct StorySourceLayout: Sendable {
    public var root: URL
    public var storyJSON: URL { root.appendingPathComponent("story.json") }
    public var textsDir: URL { root.appendingPathComponent("texts") }
    public init(root: URL) { self.root = root }
}

/// Describes the on-disk layout for a compiled directory-based story bundle.
public struct StoryBundleLayout: Sendable {
    public var root: URL
    public var manifest: URL { root.appendingPathComponent("manifest.json") }
    public var graph: URL { root.appendingPathComponent("graph.json") }
    public var textsDir: URL { root.appendingPathComponent("texts") }
    public init(root: URL) { self.root = root }
}

/// Compiles a source folder into a directory-based bundle for runtime use.
public struct StoryCompiler: Sendable {
    public init() {}

    /// Compiles a source folder into a directory-based .storybundle.
    public func compile(source: StorySourceLayout, to bundle: StoryBundleLayout) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: bundle.root, withIntermediateDirectories: true)
        try fm.createDirectory(at: bundle.textsDir, withIntermediateDirectories: true)
        // Copy story.json -> graph.json (normalized step could be added later)
        let data = try Data(contentsOf: source.storyJSON)
        try data.write(to: bundle.graph, options: .atomic)
        // Copy texts directory
        if fm.fileExists(atPath: source.textsDir.path) {
            let items = try fm.contentsOfDirectory(at: source.textsDir, includingPropertiesForKeys: nil)
            for item in items where item.pathExtension.lowercased() == "md" {
                let dest = bundle.textsDir.appendingPathComponent(item.lastPathComponent)
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: item, to: dest)
            }
        }
        // Write manifest with metadata and graph hash
        let story = try JSONDecoder().decode(Story.self, from: data)
        let manifest = StoryBundleManifest(
            schemaVersion: 1,
            storyID: story.metadata.id,
            title: story.metadata.title,
            version: story.metadata.version,
            graphHashSHA256: sha256Hex(of: data),
            builtAt: Date()
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: bundle.manifest, options: .atomic)
    }
}

/// Loads a Story from a `story.json` file.
public struct StoryLoader: Sendable {
    public init() {}

    public func loadStory(from url: URL) throws -> Story {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Story.self, from: data)
    }
}

/// Loads a Story from a compiled bundle's `graph.json` file.
public struct StoryBundleLoader: Sendable {
    public init() {}
    public func load(from bundle: StoryBundleLayout) throws -> Story {
        let data = try Data(contentsOf: bundle.graph)
        let decoder = JSONDecoder()
        return try decoder.decode(Story.self, from: data)
    }
}

/// Parses Markdown files that contain multiple node sections separated by a special token.
/// Token format (at start of line):
/// === node: <section-id> ===
/// Splits Markdown into labeled sections using lines like `=== node: <section-id> ===`.
public struct TextSectionParser: Sendable {
    public init() {}

    public func parseSections(markdown: String) -> [String: String] {
        var map: [String: String] = [:]
        var currentID: String?
        var buffer: [String] = []
        func flush() {
            if let id = currentID {
                map[id] = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            buffer.removeAll(keepingCapacity: true)
        }
        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if let id = Self.extractSectionID(from: line) {
                flush()
                currentID = id
            } else {
                buffer.append(line)
            }
        }
        flush()
        return map
    }

    private static func extractSectionID(from line: String) -> String? {
        // Strict format: === node: <section-id> ===
        // Allow extra spaces around tokens.
        let pattern = "^===\\s*node:\\s*(.*?)\\s*===\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (line as NSString).length)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }
        if match.numberOfRanges >= 2, let r = Range(match.range(at: 1), in: line) {
            let id = String(line[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : id
        }
        return nil
    }
}

// MARK: - Text Providers

/// Serves Markdown text for a given reference.
public protocol TextProvider {
    /// Returns the text for the given reference or throws if not found.
    func text(for ref: TextRef) throws -> String
}

/// A simple text provider that parses the source file each time.
public struct SourceTextProvider: TextProvider {
    private let layout: StorySourceLayout
    private let parser = TextSectionParser()

    public init(source: StorySourceLayout) { self.layout = source }

    public func text(for ref: TextRef) throws -> String {
        let url = layout.textsDir.appendingPathComponent(ref.file)
        let content = try String(contentsOf: url, encoding: .utf8)
        let map = parser.parseSections(markdown: content)
        guard let text = map[ref.section] else { throw StoryIOError.textSectionMissing(ref) }
        return text
    }
}

/// A simple text provider for compiled bundles that parses each request.
public struct BundleTextProvider: TextProvider {
    private let layout: StoryBundleLayout
    private let parser = TextSectionParser()

    public init(bundle: StoryBundleLayout) { self.layout = bundle }

    public func text(for ref: TextRef) throws -> String {
        let url = layout.textsDir.appendingPathComponent(ref.file)
        let content = try String(contentsOf: url, encoding: .utf8)
        let map = parser.parseSections(markdown: content)
        guard let text = map[ref.section] else { throw StoryIOError.textSectionMissing(ref) }
        return text
    }
}

// Actor-based cached providers
/// An actor-based provider that caches parsed source files with LRU eviction and memory pressure purge.
public actor CachedSourceTextProvider {
    private let layout: StorySourceLayout
    private let parser = TextSectionParser()
    private struct Entry { var sections: [String: String]; var size: Int; var lastAccess: UInt64 }
    private var cache: [String: Entry] = [:] // file -> entry
    private var totalSize: Int = 0
    private var accessCounter: UInt64 = 0
    private let maxBytes: Int
    private var pressureSource: DispatchSourceMemoryPressure?

    /// Creates a cached provider for a source layout.
    /// - Parameter maxBytes: Cache budget; files are evicted LRU when exceeded.
    public init(source: StorySourceLayout, maxBytes: Int = 8 * 1024 * 1024) {
        self.layout = source
        self.maxBytes = maxBytes
        Task { await Self.installPressureSource(owner: self, label: "storykit.cached-source-text-provider.pressure") }
    }

    /// Returns text for a reference, loading and caching the file if necessary.
    public func text(for ref: TextRef) throws -> String {
        if cache[ref.file] == nil {
            try loadFileIntoCache(ref.file)
        }
        accessCounter &+= 1
        if var e = cache[ref.file] { e.lastAccess = accessCounter; cache[ref.file] = e }
        guard let text = cache[ref.file]?.sections[ref.section] else { throw StoryIOError.textSectionMissing(ref) }
        return text
    }

    /// Clears all cached content.
    public func purgeAll() {
        cache.removeAll(keepingCapacity: false)
        totalSize = 0
    }

    /// Responds to system memory pressure by purging the cache.
    public func handleMemoryPressure() {
        purgeAll()
    }

    private func loadFileIntoCache(_ file: String) throws {
        let url = layout.textsDir.appendingPathComponent(file)
        let content = try String(contentsOf: url, encoding: .utf8)
        let sections = parser.parseSections(markdown: content)
        let size = sections.reduce(0) { $0 + ($1.key.utf8.count + $1.value.utf8.count) }
        accessCounter &+= 1
        if let existing = cache[file] { totalSize -= existing.size }
        cache[file] = Entry(sections: sections, size: size, lastAccess: accessCounter)
        totalSize += size
        evictIfNeeded()
    }

    private func evictIfNeeded() {
        while totalSize > maxBytes && !cache.isEmpty {
            if let (oldestFile, entry) = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess }) {
                cache.removeValue(forKey: oldestFile)
                totalSize -= entry.size
            } else { break }
        }
    }

    nonisolated private static func createMemoryPressureSource(owner: CachedSourceTextProvider, label: String) -> DispatchSourceMemoryPressure {
        let queue = DispatchQueue(label: label)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: queue)
        source.setEventHandler { [weak owner] in
            guard let owner else { return }
            let sem = DispatchSemaphore(value: 0)
            Task {
                await owner.handleMemoryPressure()
                sem.signal()
            }
            _ = sem.wait(timeout: .now() + 1.0)
        }
        source.resume()
        return source
    }

    nonisolated private static func installPressureSource(owner: CachedSourceTextProvider, label: String) async {
        let src = Self.createMemoryPressureSource(owner: owner, label: label)
        await owner._setPressureSource(src)
    }

    private func _setPressureSource(_ src: DispatchSourceMemoryPressure) {
        self.pressureSource = src
    }
}

/// An actor-based provider that caches parsed bundle files with LRU eviction and memory pressure purge.
public actor CachedBundleTextProvider {
    private let layout: StoryBundleLayout
    private let parser = TextSectionParser()
    private struct Entry { var sections: [String: String]; var size: Int; var lastAccess: UInt64 }
    private var cache: [String: Entry] = [:]
    private var totalSize: Int = 0
    private var accessCounter: UInt64 = 0
    private let maxBytes: Int
    private var pressureSource: DispatchSourceMemoryPressure?

    /// Creates a cached provider for a compiled bundle.
    /// - Parameter maxBytes: Cache budget; files are evicted LRU when exceeded.
    public init(bundle: StoryBundleLayout, maxBytes: Int = 8 * 1024 * 1024) {
        self.layout = bundle
        self.maxBytes = maxBytes
        Task { await Self.installPressureSource(owner: self, label: "storykit.cached-bundle-text-provider.pressure") }
    }

    /// Returns text for a reference, loading and caching the file if necessary.
    public func text(for ref: TextRef) throws -> String {
        if cache[ref.file] == nil {
            try loadFileIntoCache(ref.file)
        }
        accessCounter &+= 1
        if var e = cache[ref.file] { e.lastAccess = accessCounter; cache[ref.file] = e }
        guard let text = cache[ref.file]?.sections[ref.section] else { throw StoryIOError.textSectionMissing(ref) }
        return text
    }

    /// Clears all cached content.
    public func purgeAll() {
        cache.removeAll(keepingCapacity: false)
        totalSize = 0
    }

    /// Responds to system memory pressure by purging the cache.
    public func handleMemoryPressure() {
        purgeAll()
    }

    private func loadFileIntoCache(_ file: String) throws {
        let url = layout.textsDir.appendingPathComponent(file)
        let content = try String(contentsOf: url, encoding: .utf8)
        let sections = parser.parseSections(markdown: content)
        let size = sections.reduce(0) { $0 + ($1.key.utf8.count + $1.value.utf8.count) }
        accessCounter &+= 1
        if let existing = cache[file] { totalSize -= existing.size }
        cache[file] = Entry(sections: sections, size: size, lastAccess: accessCounter)
        totalSize += size
        evictIfNeeded()
    }

    private func evictIfNeeded() {
        while totalSize > maxBytes && !cache.isEmpty {
            if let (oldestFile, entry) = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess }) {
                cache.removeValue(forKey: oldestFile)
                totalSize -= entry.size
            } else { break }
        }
    }

    nonisolated private static func createMemoryPressureSource(owner: CachedBundleTextProvider, label: String) -> DispatchSourceMemoryPressure {
        let queue = DispatchQueue(label: label)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: queue)
        source.setEventHandler { [weak owner] in
            guard let owner else { return }
            let sem = DispatchSemaphore(value: 0)
            Task {
                await owner.handleMemoryPressure()
                sem.signal()
            }
            _ = sem.wait(timeout: .now() + 1.0)
        }
        source.resume()
        return source
    }

    nonisolated private static func installPressureSource(owner: CachedBundleTextProvider, label: String) async {
        let src = Self.createMemoryPressureSource(owner: owner, label: label)
        await owner._setPressureSource(src)
    }

    private func _setPressureSource(_ src: DispatchSourceMemoryPressure) {
        self.pressureSource = src
    }
}
