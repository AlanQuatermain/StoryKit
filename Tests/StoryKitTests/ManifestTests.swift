import Foundation
import Testing
@testable import ContentIO
import Core

@Test
func manifest_is_written_and_hash_matches() throws {
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

