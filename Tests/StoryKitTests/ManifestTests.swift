import Foundation
import Testing
@testable import ContentIO
import Core

@Suite("ManifestAndBundle")
struct ManifestTests {
    @Test("Manifest is written and hash matches")
    func manifestIsWrittenAndHashMatches() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let fm = FileManager.default
        try fm.createDirectory(at: source.root, withIntermediateDirectories: true)
        try fm.createDirectory(at: source.textsDir, withIntermediateDirectories: true)

        // Minimal story
        let start = NodeID(rawValue: "start")
        let story = Story(metadata: .init(id: "story-id", title: "Story Title", version: 7), start: start, nodes: [
            start: Node(id: start, text: TextRef(file: "main.md", section: "start"), choices: [])
        ])
        let data = try JSONEncoder().encode(story)
        try data.write(to: source.storyJSON)
        let md = """
        === node: start ===
        Hello
        """
        try md.write(to: source.textsDir.appendingPathComponent("main.md"), atomically: true, encoding: .utf8)

        let bundleRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".storybundle")
        let bundle = StoryBundleLayout(root: bundleRoot)
        try StoryCompiler().compile(source: source, to: bundle)

        // Validate manifest
        let manifestData = try Data(contentsOf: bundle.manifest)
        let manifest = try JSONDecoder().decode(StoryBundleManifest.self, from: manifestData)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.storyID == story.metadata.id)
        #expect(manifest.title == story.metadata.title)
        #expect(manifest.version == story.metadata.version)
        // Graph hash matches story.json data
        let expectedHash = sha256Hex(of: data)
        #expect(manifest.graphHashSHA256 == expectedHash)
    }

    @Test("Bundle loader loads story")
    func bundleLoaderLoadsStory() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let fm = FileManager.default
        try fm.createDirectory(at: source.root, withIntermediateDirectories: true)
        try fm.createDirectory(at: source.textsDir, withIntermediateDirectories: true)

        let start = NodeID(rawValue: "s")
        let end = NodeID(rawValue: "e")
        let story = Story(metadata: .init(id: "id", title: "T", version: 1), start: start, nodes: [
            start: Node(id: start, text: TextRef(file: "t.md", section: "s"), choices: [Choice(id: ChoiceID(rawValue: "c"), title: "go", destination: end)]),
            end: Node(id: end, text: TextRef(file: "t.md", section: "e"), choices: [])
        ])
        let data = try JSONEncoder().encode(story)
        try data.write(to: source.storyJSON)
        try "=== node: s ===\nS\n=== node: e ===\nE\n".write(to: source.textsDir.appendingPathComponent("t.md"), atomically: true, encoding: .utf8)

        let bundleRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".storybundle")
        let bundle = StoryBundleLayout(root: bundleRoot)
        try StoryCompiler().compile(source: source, to: bundle)
        let loaded = try StoryBundleLoader().load(from: bundle)
        #expect(loaded.metadata.id == story.metadata.id)
        #expect(loaded.nodes.count == story.nodes.count)
        #expect(loaded.start == story.start)
    }

    @Test("Bundle text provider loads and throws")
    func bundleTextProviderLoadsAndThrows() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let fm = FileManager.default
        try fm.createDirectory(at: source.root, withIntermediateDirectories: true)
        try fm.createDirectory(at: source.textsDir, withIntermediateDirectories: true)

        let a = NodeID(rawValue: "a")
        let story = Story(metadata: .init(id: "id", title: "T", version: 1), start: a, nodes: [
            a: Node(id: a, text: TextRef(file: "t.md", section: "s"), choices: [])
        ])
        let data = try JSONEncoder().encode(story)
        try data.write(to: source.storyJSON)
        try "=== node: s ===\nHELLO\n".write(to: source.textsDir.appendingPathComponent("t.md"), atomically: true, encoding: .utf8)

        let bundleRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".storybundle")
        let bundle = StoryBundleLayout(root: bundleRoot)
        try StoryCompiler().compile(source: source, to: bundle)

        let provider = BundleTextProvider(bundle: bundle)
        let ok = try provider.text(for: TextRef(file: "t.md", section: "s"))
        #expect(ok == "HELLO")
        let missing = TextRef(file: "t.md", section: "missing")
        #expect(throws: StoryIOError.textSectionMissing(missing)) {
            _ = try provider.text(for: missing)
        }
    }

    @Test("Bundle validation orphan warnings")
    func bundleValidationOrphanWarnings() throws {
        // Create a story and bundle with an extra unreferenced section and file
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let fm = FileManager.default
        try fm.createDirectory(at: source.root, withIntermediateDirectories: true)
        try fm.createDirectory(at: source.textsDir, withIntermediateDirectories: true)

        let a = NodeID(rawValue: "a")
        let story = Story(metadata: .init(id: "id", title: "T", version: 1), start: a, nodes: [
            a: Node(id: a, text: TextRef(file: "t.md", section: "s"), choices: [])
        ])
        let data = try JSONEncoder().encode(story)
        try data.write(to: source.storyJSON)
        try "=== node: s ===\nHELLO\n=== node: extra ===\nE\n".write(to: source.textsDir.appendingPathComponent("t.md"), atomically: true, encoding: .utf8)
        try "=== node: u ===\nU\n".write(to: source.textsDir.appendingPathComponent("u.md"), atomically: true, encoding: .utf8)

        let bundleRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".storybundle")
        let bundle = StoryBundleLayout(root: bundleRoot)
        try StoryCompiler().compile(source: source, to: bundle)

        let loaded = try StoryBundleLoader().load(from: bundle)
        let issues = StoryValidator().validate(story: loaded, bundle: bundle)
        #expect(issues.contains { $0.kind == .orphanTextSection && $0.severity == .warning })
        #expect(issues.contains { $0.kind == .orphanMarkdownFile && $0.severity == .warning })
    }

    @Test("StoryLoader fails on malformed JSON")
    func storyLoaderFailsOnMalformedJSON() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        try FileManager.default.createDirectory(at: source.root, withIntermediateDirectories: true)
        // Write malformed JSON
        try "{".write(to: source.storyJSON, atomically: true, encoding: .utf8)
        #expect(throws: DecodingError.self) {
            _ = try StoryLoader().loadStory(from: source.storyJSON)
        }
    }

    @Test("BundleLoader fails on malformed graph")
    func bundleLoaderFailsOnMalformedGraph() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".storybundle")
        let bundle = StoryBundleLayout(root: root)
        let fm = FileManager.default
        try fm.createDirectory(at: bundle.root, withIntermediateDirectories: true)
        try fm.createDirectory(at: bundle.textsDir, withIntermediateDirectories: true)
        // Malformed graph.json
        try "not json".write(to: bundle.graph, atomically: true, encoding: .utf8)
        // Minimal manifest so validator thinks it's a bundle
        try "{\"schemaVersion\":1}".write(to: bundle.manifest, atomically: true, encoding: .utf8)
        #expect(throws: DecodingError.self) {
            _ = try StoryBundleLoader().load(from: bundle)
        }
    }
}
