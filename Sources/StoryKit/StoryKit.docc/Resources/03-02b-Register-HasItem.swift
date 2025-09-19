import StoryKit

public func makePredicates() -> PredicateRegistry<HauntedState> {
    var preds = PredicateRegistry<HauntedState>()
    preds.register("has-item") { state, params in
        guard let id = params["item"] else { return false }
        return state.inventory.contains(id)
    }
    return preds
}

