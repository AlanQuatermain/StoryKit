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
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let range = line.range(of: "^===\\s*node:\\s*(.+?)\\s*===\\s*$", options: [.regularExpression]) {
                flush()
                let id = String(line[range]).replacingOccurrences(of: "===", with: "")
                    .replacingOccurrences(of: "node:", with: "")
                    .replacingOccurrences(of: "=", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentID = id
            } else {
                buffer.append(line)
            }
        }
        flush()
        return map
    }
}

