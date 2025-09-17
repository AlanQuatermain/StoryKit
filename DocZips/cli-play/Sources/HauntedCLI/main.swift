import StoryKit
import Foundation

struct EmptyState: StoryState, Codable, Sendable { var currentNode: NodeID }

@main
struct HauntedCLI {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("../Sources/StoryKit/StoryKit.docc/Resources/stories/haunted-bundle")
        let layout = StoryBundleLayout(root: root)
        let story = try StoryBundleLoader().load(from: layout)
        let engine = StoryEngine(story: story, initialState: EmptyState(currentNode: story.start))
        let provider = BundleTextProvider(bundle: layout)
        while let node = await engine.currentNode() {
            let text = try provider.text(for: node.text)
            print("\n" + text + "\n")
            let choices = await engine.availableChoices()
            if choices.isEmpty { break }
            for (i,c) in choices.enumerated() { print("\(i+1). \(c.title ?? c.id.rawValue)") }
            print("Enter choice:", terminator: " ")
            guard let line = readLine(), let n = Int(line), n>0, n<=choices.count else { continue }
            _ = try await engine.select(choiceID: choices[n-1].id)
        }
    }
}
