import Foundation
import Core

public enum StoryIOError: Error {
    case invalidPath
    case decodeFailed
    case textSectionMissing(TextRef)
}

public struct StorySourceLayout: Sendable {
    public var root: URL
    public var storyJSON: URL { root.appendingPathComponent("story.json") }
    public var textsDir: URL { root.appendingPathComponent("texts") }
    public init(root: URL) { self.root = root }
}

public struct StoryBundleLayout: Sendable {
    public var root: URL
    public var manifest: URL { root.appendingPathComponent("manifest.json") }
    public var graph: URL { root.appendingPathComponent("graph.json") }
    public var textsDir: URL { root.appendingPathComponent("texts") }
    public init(root: URL) { self.root = root }
}

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
        // Write minimal manifest
        let manifest = ["schemaVersion": 1] as [String : Any]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: bundle.manifest, options: .atomic)
    }
}

public struct StoryLoader: Sendable {
    public init() {}

    public func loadStory(from url: URL) throws -> Story {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Story.self, from: data)
    }
}

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

public protocol TextProvider {
    func text(for ref: TextRef) throws -> String
}

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
