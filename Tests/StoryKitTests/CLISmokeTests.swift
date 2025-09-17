import Foundation
import Testing
import ContentIO
import Core

@Suite("CLI Smoke Test")
struct CLISmokeTests {
    @Test("HauntedCLI runs non-interactively against compiled bundle")
    func hauntedCLIRuns() async throws {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let zipsDir = cwd.appendingPathComponent("Sources/StoryKit/StoryKit.docc/Resources/zips")
        let afterZip = zipsDir.appendingPathComponent("haunted-after.zip")
        #expect(fm.fileExists(atPath: afterZip.path))

        // Create temp working dir
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Unzip haunted-after.zip
        try run("/usr/bin/unzip", args: [afterZip.path, "-d", tmp.path])
        let direct = tmp.appendingPathComponent("story.json")
        let srcRoot: URL
        if fm.fileExists(atPath: direct.path) {
            srcRoot = tmp
        } else {
            let contents = try fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)
            srcRoot = contents.first(where: { url in
                var isDir: ObjCBool = false
                return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
            }) ?? tmp
        }

        // Compile to bundle
        let bundleRoot = tmp.appendingPathComponent("bundle")
        try StoryCompiler().compile(source: .init(root: srcRoot), to: .init(root: bundleRoot))
        #expect(fm.fileExists(atPath: bundleRoot.appendingPathComponent("graph.json").path))

        // Locate HauntedCLI binary
        let candidates = [
            cwd.appendingPathComponent(".build/debug/HauntedCLI"),
            cwd.appendingPathComponent(".build/arm64-apple-macosx/debug/HauntedCLI"),
            cwd.appendingPathComponent(".build/x86_64-apple-macosx/debug/HauntedCLI")
        ]
        guard let bin = candidates.first(where: { fm.isExecutableFile(atPath: $0.path) }) else {
            Issue.record("HauntedCLI binary not found; build the product first.")
            return
        }

        // Run CLI with two choices then EOF
        let output = try run(bin.path, args: [], env: ["HAUNTED_BUNDLE": bundleRoot.path], input: "1\n1\n")
        #expect(output.contains("Enter the east hall") || output.contains("Enter the west hall"))
    }
}

@discardableResult
private func run(_ tool: String, args: [String], env: [String:String] = [:], input: String? = nil) throws -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    var fullEnv = ProcessInfo.processInfo.environment
    env.forEach { fullEnv[$0] = $1 }
    p.environment = fullEnv

    let outPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = outPipe
    let inPipe = Pipe()
    p.standardInput = inPipe

    try p.run()
    if let inputData = input?.data(using: .utf8) {
        inPipe.fileHandleForWriting.write(inputData)
        try? inPipe.fileHandleForWriting.close()
    }
    p.waitUntilExit()
    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}
