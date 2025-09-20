import StoryKit

public func ritualOutcome(into acts: inout ActionRegistry<HauntedState>) {
    acts.register("ritual") { state, params in
        let order = (params["order"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if ritualChecks(state, order: order) {
            state.setFlag("ritual_success", to: true)
            return .completed
        } else {
            state.setFlag("ritual_failed", to: true)
            return .completed
        }
    }
}

