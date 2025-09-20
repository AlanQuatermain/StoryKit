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

    // Step 3: print node header and prose
    let textProvider = BundleTextProvider(bundle: StoryBundleLayout(root: URL(fileURLWithPath: bundlePath)))
    if let node = await engine.currentNode() {
        print("\n=== \(node.id.rawValue) ===\n")
        let text = try textProvider.text(for: node.text)
        print("\n\(text)\n")
    }
}

