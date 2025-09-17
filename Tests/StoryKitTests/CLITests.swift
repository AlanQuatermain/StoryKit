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

    @Test("Validate fixture summary text")
    func validateFixtureSummaryText() throws {
        guard let bin = findBinary(named: "storykit") else { return }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fx = cwd.appendingPathComponent("Tests/Fixtures/TinyStory")
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["validate", fx.path], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        #expect(out.contains("Entities ("))
        #expect(out.contains("rat"))
        #expect(out.contains("Actors by node:"))
        #expect(out.contains("start"))
        #expect(out.contains("r1"))
    }

    @Test("Validate fixture summary JSON")
    func validateFixtureSummaryJSON() throws {
        guard let bin = findBinary(named: "storykit") else { return }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fx = cwd.appendingPathComponent("Tests/Fixtures/TinyStory")
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["validate", fx.path, "--format", "json"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        struct Report: Decodable {
            struct Summary: Decodable {
                struct Entity: Decodable { let id: String; let name: String?; let tags: [String] }
                struct NodeActors: Decodable { let node: String; let actors: [Actor] }
                struct Actor: Decodable { let id: String; let ref: String?; let name: String?; let tags: [String] }
                let entities: [Entity]
                let actorsByNode: [NodeActors]
            }
            let summary: Summary
        }
        let report = try JSONDecoder().decode(Report.self, from: data)
        #expect(report.summary.entities.contains { $0.id == "rat" && ($0.name ?? "") == "Rat" && $0.tags.contains("hostile") })
        #expect(report.summary.actorsByNode.contains { $0.node == "start" && $0.actors.contains { $0.id == "r1" && $0.ref == "rat" } })
    }

    @Test("Validate --summary-only text")
    func validateSummaryOnlyText() throws {
        guard let bin = findBinary(named: "storykit") else { return }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fx = cwd.appendingPathComponent("Tests/Fixtures/TinyStory")
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["validate", fx.path, "--summary-only"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        #expect(out.contains("Entities (1):"))
        #expect(out.contains("rat"))
        #expect(out.contains("- [WARNING]") == false)
        #expect(out.contains("- [ERROR]") == false)
    }

    @Test("Validate --no-summary text")
    func validateNoSummaryText() throws {
        guard let bin = findBinary(named: "storykit") else { return }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fx = cwd.appendingPathComponent("Tests/Fixtures/TinyStory")
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["validate", fx.path, "--no-summary"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        #expect(out.contains("- [WARNING] Node has no choices: end"))
        #expect(out.contains("Entities (") == false)
        #expect(out.contains("Actors by node:") == false)
    }

    @Test("Validate --summary-only JSON")
    func validateSummaryOnlyJSON() throws {
        guard let bin = findBinary(named: "storykit") else { return }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fx = cwd.appendingPathComponent("Tests/Fixtures/TinyStory")
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["validate", fx.path, "--format", "json", "--summary-only"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        struct Summary: Decodable {
            struct Entity: Decodable { let id: String; let name: String?; let tags: [String] }
            struct NodeActors: Decodable { let node: String; let actors: [Actor] }
            struct Actor: Decodable { let id: String; let ref: String?; let name: String?; let tags: [String] }
            let entities: [Entity]
            let actorsByNode: [NodeActors]
        }
        let summary = try JSONDecoder().decode(Summary.self, from: data)
        #expect(summary.entities.contains { $0.id == "rat" })
        #expect(summary.actorsByNode.contains { $0.node == "start" && $0.actors.contains { $0.id == "r1" && $0.ref == "rat" } })
    }

    @Test("Validate --no-summary JSON")
    func validateNoSummaryJSON() throws {
        guard let bin = findBinary(named: "storykit") else { return }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fx = cwd.appendingPathComponent("Tests/Fixtures/TinyStory")
        let pipe = Pipe()
        let status = try runProcess(bin, args: ["validate", fx.path, "--format", "json", "--no-summary"], stdout: pipe)
        #expect(status == 0)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        #expect(obj?["summary"] == nil)
        #expect((obj?["ok"] as? Bool) != nil)
        #expect((obj?["issues"] as? [Any]) != nil)
    }
}
#endif
