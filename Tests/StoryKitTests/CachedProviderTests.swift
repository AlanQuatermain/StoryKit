import Foundation
import Testing
import StoryKit

private func writeMarkdown(_ url: URL, sections: [(String, String)]) throws {
    var s = ""
    for (id, body) in sections {
        s += "=== node: \(id) ===\n"
        s += body
        s += "\n"
    }
    try s.write(to: url, atomically: true, encoding: .utf8)
}

@Suite("CachedTextProviders")
struct CachedProviderTests {
    @Test("Cached source eviction and reload")
    func cachedSourceEvictionAndReload() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let fm = FileManager.default
        try fm.createDirectory(at: source.textsDir, withIntermediateDirectories: true)

        let f1 = source.textsDir.appendingPathComponent("f1.md")
        let f2 = source.textsDir.appendingPathComponent("f2.md")
        let bigBody = String(repeating: "A", count: 2048)
        try writeMarkdown(f1, sections: [("a", bigBody)])
        try writeMarkdown(f2, sections: [("b", bigBody)])

        // Set maxBytes slightly larger than f1 but smaller than f1+f2
        let approxSize = ("a".utf8.count + bigBody.utf8.count)
        let provider = CachedSourceTextProvider(source: source, maxBytes: approxSize + 16)

        // Load f1 -> cached
        let t1 = try await provider.text(for: TextRef(file: "f1.md", section: "a"))
        #expect(t1 == bigBody)

        // Modify f1 on disk to detect reload later
        let newBody = String(repeating: "B", count: 1024)
        try writeMarkdown(f1, sections: [("a", newBody)])

        // Load f2 to push over capacity; should evict f1 (LRU)
        _ = try await provider.text(for: TextRef(file: "f2.md", section: "b"))

        // Access f1 again -> should reload from disk and see new content
        let t1Reload = try await provider.text(for: TextRef(file: "f1.md", section: "a"))
        #expect(t1Reload == newBody)
    }

    @Test("Cached source memory pressure purges")
    func cachedSourceMemoryPressurePurges() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let fm = FileManager.default
        try fm.createDirectory(at: source.textsDir, withIntermediateDirectories: true)

        let f = source.textsDir.appendingPathComponent("f.md")
        try writeMarkdown(f, sections: [("s", "Hello")])
        let provider = CachedSourceTextProvider(source: source)
        _ = try await provider.text(for: TextRef(file: "f.md", section: "s"))

        // Change content on disk
        try writeMarkdown(f, sections: [("s", "World")])

        // Simulate memory pressure purge
        await provider.handleMemoryPressure()

        let t = try await provider.text(for: TextRef(file: "f.md", section: "s"))
        #expect(t == "World")
    }

    @Test("Source provider missing file throws")
    func sourceProviderMissingFileThrows() async {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let provider = CachedSourceTextProvider(source: source)
        await #expect(throws: Error.self) {
            _ = try await provider.text(for: TextRef(file: "missing.md", section: "s"))
        }
    }

    @Test("Bundle provider missing file throws")
    func bundleProviderMissingFileThrows() async {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".storybundle")
        let bundle = StoryBundleLayout(root: root)
        try? FileManager.default.createDirectory(at: bundle.root, withIntermediateDirectories: true)
        // Ensure texts dir exists but empty
        try? FileManager.default.createDirectory(at: bundle.textsDir, withIntermediateDirectories: true)
        let provider = CachedBundleTextProvider(bundle: bundle)
        await #expect(throws: Error.self) {
            _ = try await provider.text(for: TextRef(file: "missing.md", section: "s"))
        }
    }
}
