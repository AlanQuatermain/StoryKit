import StoryKit

public func registerRitual(into acts: inout ActionRegistry<HauntedState>) {
    acts.register("ritual") { state, params in
        let order = (params["order"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        // More logic in later steps…
        return .requiresUserInput
    }
}

