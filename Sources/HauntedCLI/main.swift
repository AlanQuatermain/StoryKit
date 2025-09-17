import StoryKit
import Foundation

struct EmptyState: StoryState, Codable, Sendable {
    var currentNode: NodeID
}

@main
struct HauntedCLI {
    static func main() async throws {
        let env = ProcessInfo.processInfo.environment
        let argPath = CommandLine.arguments.dropFirst().first
        let rootPath = argPath ?? env["HAUNTED_BUNDLE"]
        let layout: StoryBundleLayout
        if let rootPath {
            layout = StoryBundleLayout(root: URL(fileURLWithPath: rootPath))
        } else {
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            layout = StoryBundleLayout(root: cwd.appendingPathComponent("Sources/StoryKit/StoryKit.docc/Resources/stories/haunted-bundle"))
        }
        let story = try StoryBundleLoader().load(from: layout)

        var engine = StoryEngine(story: story, initialState: EmptyState(currentNode: story.start))
        // For this minimal loop, no custom predicates/effects/actions are registered.

        let textProvider = BundleTextProvider(bundle: layout)

        func render(_ node: Node) async throws {
            let t = try textProvider.text(for: node.text)
            print("\n" + t + "\n")
            let choices = await engine.availableChoices()
            if choices.isEmpty { return }
            for (i, c) in choices.enumerated() {
                print("\(i+1). \(c.title ?? c.id.rawValue)")
            }
        }

        while true {
            guard let node = await engine.currentNode() else { break }
            try await render(node)
            let choices = await engine.availableChoices()
            if choices.isEmpty { break }
            print("Enter choice:", terminator: " ")
            guard let line = readLine() else { break }
            guard let n = Int(line), n > 0, n <= choices.count else { continue }
            _ = try await engine.select(choiceID: choices[n-1].id)
        }
    }
}
