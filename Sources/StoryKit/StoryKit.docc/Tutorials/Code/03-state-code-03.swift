import StoryKit

enum BattleError: Error { case defeated }

func registerActions(into acts: inout ActionRegistry<PlayerState>) {
    acts.register("player_died") { state, _ in
        // The main loop should call performGlobalAction("player_died") when appropriate.
        throw BattleError.defeated
    }
}

// Example encounter driver using actions and global actions
func handleWestHallEncounter(engine: StoryEngine<PlayerState>) async {
    // A sketch: in a real loop, you’d check state and present choices.
    do {
        // If some condition indicates defeat, trigger global action
        _ = try await engine.performGlobalAction(id: "player_died")
    } catch {
        // Handle error
    }
}

