import StoryKit

public func registerEffects(into registry: inout EffectRegistry<HauntedState>) {
    registry.register("lose-sanity") { state, params in
        let amount = Int(params["amount"] ?? "1") ?? 1
        state.sanity = max(0, state.sanity - amount)
    }
    registry.register("take-damage") { state, params in
        let amount = Int(params["amount"] ?? "1") ?? 1
        state.health = max(0, state.health - amount)
    }
    registry.register("gain-item") { state, params in
        if let item = params["item"] { state.inventory.insert(item) }
    }
    registry.register("set-flag") { state, params in
        guard let flag = params["flag"], let v = params["value"]?.lowercased() else { return }
        state.flags[flag] = (v == "true" || v == "1")
    }
}

