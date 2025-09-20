import StoryKit

public func registerMeleeRound(into acts: inout ActionRegistry<HauntedState>) {
    acts.register("melee-round") { state, params in
        // Narratively: attempt a hit against an enemy; enemy may retaliate.
        // This sample hints at mechanics; a real version tracks enemy hp in state.
        let hit = rollD20() > 10
        if hit {
            // e.g., set a flag for narration
            state.setFlag("lastHit", to: true)
        } else {
            // retaliation knocks sanity a bit
            state.sanity = max(0, state.sanity - 1)
        }
        return .requiresUserInput
    }
}

