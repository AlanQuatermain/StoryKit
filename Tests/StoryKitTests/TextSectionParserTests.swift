import Foundation
import Testing
@testable import ContentIO
import Core

@Suite("TextSectionParser")
struct TextSectionParserTests {
    @Test
    func parsesMultipleSectionsWithWhitespace() {
        let md = """
        === node: one ===
        A
        
        ===  node:   two   ===
        B
        === node:three===
        C
        """
        let map = TextSectionParser().parseSections(markdown: md)
        #expect(map["one"] == "A")
        #expect(map["two"] == "B")
        #expect(map["three"] == "C")
    }

    @Test
    func missingSectionThrows() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        try FileManager.default.createDirectory(at: source.textsDir, withIntermediateDirectories: true)
        let url = source.textsDir.appendingPathComponent("t.md")
        try "=== node: a ===\nA\n".write(to: url, atomically: true, encoding: .utf8)
        let provider = SourceTextProvider(source: source)
        let ref = TextRef(file: "t.md", section: "missing")
        #expect(throws: StoryIOError.textSectionMissing(ref)) { _ = try provider.text(for: ref) }
    }

    @Test
    func noSectionHeadersProducesEmptyMap() {
        let md = "No section header here\nJust body text\n=== not a header==\n"
        let map = TextSectionParser().parseSections(markdown: md)
        #expect(map.isEmpty)
    }

    @Test
    func malformedHeaderDoesNotStartSection() {
        let md = "== node: a ==\nBody\n==== node: b ===\nBody2\n=== node b ===\n"
        let map = TextSectionParser().parseSections(markdown: md)
        // None of the malformed lines match the strict header pattern
        #expect(map.isEmpty)
    }
}
