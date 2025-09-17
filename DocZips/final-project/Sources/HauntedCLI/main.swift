import StoryKit
import Foundation

struct PlayerState: StoryState, Codable, Sendable {
    var currentNode: NodeID
    var hitPoints: Int = 10
    var sanity: Int = 12
    var inventory: [String] = []
}

func makeRegistries() -> (PredicateRegistry<PlayerState>, EffectRegistry<PlayerState>, ActionRegistry<PlayerState>) {
    var preds = PredicateRegistry<PlayerState>()
    var effs = EffectRegistry<PlayerState>()
    var acts = ActionRegistry<PlayerState>()
    preds.register("sanity_check") { $0.sanity >= (Int($1["dc"] ?? "10") ?? 10) }
    preds.register("has_item") { $0.inventory.contains($1["id"] ?? "") }
    effs.register("gain_item") { s,p in if let id = p["id"], !s.inventory.contains(id) { s.inventory.append(id) } }
    effs.register("lose_sanity") { s,p in s.sanity = max(0, s.sanity - (Int(p["amount"] ?? "1") ?? 1)) }
    return (preds, effs, acts)
}

@main
struct HauntedFinal {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("../Sources/StoryKit/StoryKit.docc/Resources/stories/haunted-bundle")
        let layout = StoryBundleLayout(root: root)
        let story = try StoryBundleLoader().load(from: layout)
        let (preds, effs, acts) = makeRegistries()
        let engine = StoryEngine(story: story, initialState: PlayerState(currentNode: story.start), predicateRegistry: preds, effectRegistry: effs, actionRegistry: acts)
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
