import StoryKit

public func addStatAtLeast(to preds: inout PredicateRegistry<HauntedState>) {
    preds.register("stat-at-least") { state, params in
        guard let key = params["stat"], let minStr = params["min"], let min = Int(minStr) else { return false }
        switch key {
        case "health": return state.health >= min
        case "sanity": return state.sanity >= min
        default: return false
        }
    }
}

