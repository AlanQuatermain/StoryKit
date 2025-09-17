import StoryKit

func makeRegistries() -> (PredicateRegistry<PlayerState>, EffectRegistry<PlayerState>, ActionRegistry<PlayerState>) {
    var preds = PredicateRegistry<PlayerState>()
    var effs = EffectRegistry<PlayerState>()
    var acts = ActionRegistry<PlayerState>()

    // Predicates
    preds.register("sanity_check") { state, args in
        let dc = Int(args["dc"] ?? "10") ?? 10
        return state.sanity >= dc
    }
    preds.register("has_item") { state, args in
        guard let item = args["id"] else { return false }
        return state.inventory.contains(item)
    }

    // Effects
    effs.register("gain_item") { state, args in
        if let id = args["id"], !state.inventory.contains(id) { state.inventory.append(id) }
    }
    effs.register("lose_sanity") { state, args in
        let amt = Int(args["amount"] ?? "1") ?? 1
        state.sanity = max(0, state.sanity - amt)
    }
    effs.register("heal") { state, args in
        let amt = Int(args["amount"] ?? "1") ?? 1
        state.hitPoints += amt
    }

    return (preds, effs, acts)
}

