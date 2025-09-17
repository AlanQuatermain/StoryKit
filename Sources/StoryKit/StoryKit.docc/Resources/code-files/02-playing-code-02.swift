import StoryKit
import Foundation

struct EmptyState: StoryState, Codable, Sendable {
    var currentNode: NodeID
}

@main
struct HauntedCLI {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/StoryKit/StoryKit.docc/Resources/stories/haunted-bundle")
        let layout = StoryBundleLayout(root: root)
        let story = try StoryBundleLoader().load(from: layout)

        let engine = StoryEngine(story: story, initialState: EmptyState(currentNode: story.start))
        try await play(engine: engine)
    }

    static func play(engine: StoryEngine<EmptyState>) async throws {
        func render(_ node: Node, using provider: BundleTextProvider) throws {
            let text = try provider.text(for: node.text)
            print("\n" + text + "\n")
            let choices = await engine.availableChoices()
            if choices.isEmpty { return }
            for (idx, c) in choices.enumerated() { print("\(idx+1). \(c.title ?? c.id.rawValue)") }
        }

        let provider = BundleTextProvider(bundle: StoryBundleLayout(root: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/StoryKit/StoryKit.docc/Resources/stories/haunted-bundle")))
        while let node = await engine.currentNode() ?? { await engine.state.currentNode = (await engine.story).start; return await engine.currentNode() }() {
            try render(node, using: provider)
            let choices = await engine.availableChoices()
            if choices.isEmpty { break }
            
            print("Enter choice:", terminator: " ")
            guard let line = readLine(), let n = Int(line), n > 0, n <= choices.count else { continue }
            _ = try await engine.select(choiceID: choices[n-1].id)
        }
    }
}

