import Foundation
import Testing
import Core
import ContentIO
import Engine

@Suite("Tutorials — Broken vs Fixed Validation")
struct TutorialsValidationTests {
    func repoURL() -> URL {
        // Start from current working directory of tests
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func path(_ components: String...) -> URL {
        components.reduce(repoURL()) { $0.appendingPathComponent($1) }
    }

    @Test("Broken story reports errors")
    func brokenStoryHasErrors() throws {
        let root = try unzipZip(named: "haunted-before.zip")
        let story = try StoryLoader().loadStory(from: root.appendingPathComponent("story.json"))
        let issues = StoryValidator().validate(story: story, source: .init(root: root))
        #expect(issues.contains { $0.severity == .error })
    }

    @Test("Fixed story has 0 errors")
    func fixedStoryHasNoErrors() throws {
        let root = try unzipZip(named: "haunted-after.zip")
        let story = try StoryLoader().loadStory(from: root.appendingPathComponent("story.json"))
        let issues = StoryValidator().validate(story: story, source: .init(root: root))
        #expect(!issues.contains { $0.severity == .error })
    }

    func unzipZip(named: String) throws -> URL {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let zipsDir = cwd.appendingPathComponent("Sources/StoryKit/StoryKit.docc/Resources/zips")
        let zipURL = zipsDir.appendingPathComponent(named)
        #expect(fm.fileExists(atPath: zipURL.path))
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        try run("/usr/bin/unzip", args: [zipURL.path, "-d", tmp.path])
        // Detect whether files were zipped with or without a top-level folder
        let storyJSON = tmp.appendingPathComponent("story.json")
        if fm.fileExists(atPath: storyJSON.path) { return tmp }
        // Otherwise pick the single subfolder
        let contents = try fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)
        if let firstDir = contents.first(where: { url in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }) {
            return firstDir
        }
        return tmp
    }
}

@discardableResult
private func run(_ tool: String, args: [String]) throws -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    let out = Pipe()
    p.standardOutput = out
    p.standardError = out
    try p.run()
    p.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}

@Suite("Tutorials — Engine Play Smoke Test")
struct TutorialsEngineTests {
    struct TState: StoryState, Codable, Sendable { var currentNode: NodeID }

    @Test("Engine can load bundle and step")
    func engineSteps() async throws {
        // Compile from the fixed zip into a temporary bundle, then load
        let fm = FileManager.default
        let srcRoot = try TutorialsValidationTests().unzipZip(named: "haunted-after.zip")
        let bundleRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try StoryCompiler().compile(source: .init(root: srcRoot), to: .init(root: bundleRoot))
        let story = try StoryBundleLoader().load(from: .init(root: bundleRoot))
        let engine = StoryEngine(story: story, initialState: TState(currentNode: story.start))
        #expect(await engine.currentNode() != nil)
        let choices1 = await engine.availableChoices()
        #expect(!choices1.isEmpty)
        _ = try await engine.select(choiceID: choices1[0].id)
        let choices2 = await engine.availableChoices()
        #expect(!choices2.isEmpty)
    }
}
