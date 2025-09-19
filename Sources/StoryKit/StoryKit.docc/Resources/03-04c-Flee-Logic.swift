import StoryKit

public func addFleeSupport(into acts: inout ActionRegistry<HauntedState>) {
    acts.register("flee") { state, params in
        let dex = Int(params["dex"] ?? "10") ?? 10
        if checkUnder(dex) {
            state.setFlag("fledCombat", to: true)
            return .completed
        }
        return .requiresUserInput
    }
}

