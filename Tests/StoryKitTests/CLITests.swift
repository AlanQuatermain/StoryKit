import Foundation
import Testing

#if swift(>=6.2)
@Suite("CLI")
struct CLITests {
    private func makeValidSource() throws -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let fm = FileManager.default
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let texts = tmp.appendingPathComponent("texts")
        try fm.createDirectory(at: texts, withIntermediateDirectories: true)
        let storyJSON = tmp.appendingPathComponent("story.json")
        let md = texts.appendingPathComponent("t.md")
        let story = """
        {"metadata":{"id":"id","title":"T","version":1},"start":"a","nodes":{"a":{"id":"a","text":{"file":"t.md","section":"a"},"tags":[],"onEnter":[],"choices":[{"id":"go","title":"Go","destination":"b","predicates":[],"effects":[]}]},"b":{"id":"b","text":{"file":"t.md","section":"b"},"tags":[],"onEnter":[],"choices":[]}}}
        """
        try story.write(to: storyJSON, atomically: true, encoding: .utf8)
        try "=== node: a ===\nA\n=== node: b ===\nB\n".write(to: md, atomically: true, encoding: .utf8)
        return tmp
    }

    private func makeInvalidSource() throws -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let fm = FileManager.default
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let texts = tmp.appendingPathComponent("texts")
        try fm.createDirectory(at: texts, withIntermediateDirectories: true)
        let storyJSON = tmp.appendingPathComponent("story.json")
        let story = """
        {"metadata":{"id":"id","title":"T","version":1},"start":"a","nodes":{"a":{"id":"a","text":{"file":"t.md","section":"a"},"tags":[],"onEnter":[],"choices":[{"id":"go","title":"Go","destination":"missing","predicates":[],"effects":[]}]}}}
        """
        try story.write(to: storyJSON, atomically: true, encoding: .utf8)
        try "=== node: a ===\nA\n".write(to: texts.appendingPathComponent("t.md"), atomically: true, encoding: .utf8)
        return tmp
    }

    private func findBinary(named: String) -> URL? {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            cwd.appendingPathComponent(".build/debug/\(named)"),
            cwd.appendingPathComponent(".build/arm64-apple-macosx/debug/\(named)"),
            cwd.appendingPathComponent(".build/x86_64-apple-macosx/debug/\(named)")
        ]
        for url in candidates where fm.fileExists(atPath: url.path) { return url }
        return nil
    }

    private func runProcess(_ bin: URL, args: [String], stdout: Pipe? = nil) throws -> Int32 {
        let p = Process()
        p.executableURL = bin
        p.arguments = args
        if let stdout { p.standardOutput = stdout }
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    @Test("Validate text OK exits zero")
    func validateTextOkExitsZero() throws {
        let src = try makeValidSource()
        guard let bin = findBinary(named: "storykit") else { return }
        let status = try runProcess(bin, args: ["validate", src.path])
        #expect(status == 0)
    }

    @Test("Validate text errors exit non-zero")
    func validateTextErrorsExitNonZero() throws {
        let src = try makeInvalidSource()
        guard let bin = findBinary(named: "storykit") else { return }
        let status = try runProcess(bin, args: ["validate", src.path])
        #expect(status != 0)
    }

    @Test("Validate JSON errors exit non-zero")
    func validateJSONErrorsExitNonZero() throws {
        let src = try makeInvalidSource()
        guard let bin = findBinary(named: "storykit") else { return }
        let status = try runProcess(bin, args: ["validate", src.path, "--format", "json"])
        #expect(status != 0)
    }

    @Test("Compile produces bundle")
    func compileProducesBundle() throws {
        let src = try makeValidSource()
        let out = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".storybundle")
        guard let bin = findBinary(named: "storykit") else { return }
        let status = try runProcess(bin, args: ["compile", src.path, "--out", out.path])
        #expect(status == 0)
        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("graph.json").path))
        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("manifest.json").path))
    }

    @Test("Graph DOT writes to stdout")
    func graphDotWritesToStdout() throws {
        let src = try makeValidSource()
        guard let bin = findBinary(named: "storykit") else { return }
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["graph", src.path, "--format", "dot"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        #expect(out.contains("digraph Story"))
        #expect(out.contains("\"a\" -> \"b\";"))
    }

    @Test("Graph JSON writes to stdout")
    func graphJsonWritesToStdout() throws {
        let src = try makeValidSource()
        guard let bin = findBinary(named: "storykit") else { return }
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["graph", src.path, "--format", "json"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        struct Edge: Decodable { let from: String; let to: String }
        let edges = try JSONDecoder().decode([Edge].self, from: data)
        #expect(edges.contains { $0.from == "a" && $0.to == "b" })
    }

    @Test("Graph text writes to stdout")
    func graphTextWritesToStdout() throws {
        let src = try makeValidSource()
        guard let bin = findBinary(named: "storykit") else { return }
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["graph", src.path, "--format", "text"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        #expect(out.contains("a -> b"))
    }
}
#endif
