import StoryKit

public enum RitualOutcome { case allGood, madness, scarred }

public func registerRitual(into actions: inout ActionRegistry<HauntedState>) {
    actions.register("ritual") { state, params in
        // Expected items: candle, tome, dagger, missive; order: candle → tome → dagger
        guard state.has("black_candle"), state.has("forbidden_tome"), state.has("silver_dagger") else {
            state.setFlag("ritual_failed", to: true)
            return .completed
        }
        let order = (params["order"] ?? "").split(separator: ",").map { String($0) }
        if order == ["candle", "tome", "dagger"] {
            state.setFlag("ritual_succeeded", to: true)
            return .completed
        } else {
            state.setFlag("ritual_misordered", to: true)
            return .completed
        }
    }
}

