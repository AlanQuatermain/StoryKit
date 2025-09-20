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

    // Step 2: print a header for the current node
    if let node = await engine.currentNode() {
        print("\n=== \(node.id.rawValue) ===\n")
    }
}

