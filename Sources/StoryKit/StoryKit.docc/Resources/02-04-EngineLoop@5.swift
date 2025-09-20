import Foundation
import StoryKit

public func play(story: Story, bundlePath: String) throws {
    var predicates = PredicateRegistry<HauntedState>()
    var effects = EffectRegistry<HauntedState>()
    var actions = ActionRegistry<HauntedState>()

    let engine = StoryEngine(
        story: story,
        initialState: HauntedState(start: story.start),
        predicateRegistry: predicates,
        effectRegistry: effects,
        actionRegistry: actions
    )

    let textProvider = BundleTextProvider(bundle: StoryBundleLayout(root: URL(fileURLWithPath: bundlePath)))

    while true {
        guard let node = await engine.currentNode() else { break }
        print("\n=== \(node.id.rawValue) ===\n")
        let text = try textProvider.text(for: node.text)
        print("\n\(text)\n")
        let choices = await engine.availableChoices()
        if choices.isEmpty { break }
        for (idx, c) in choices.enumerated() {
            print("  [\(idx + 1)] \(c.title ?? c.id.rawValue)")
        }
        print("\nChoose: ", terminator: "")
        guard let line = readLine(), let n = Int(line), n > 0, n <= choices.count else { continue }
        let selected = choices[n - 1]
        _ = try await engine.select(choiceID: selected.id)
    }
}

