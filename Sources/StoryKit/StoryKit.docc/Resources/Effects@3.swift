import StoryKit

public func registerLoseSanity(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("lose-sanity") { state, params in
        let amt = Int(params["by"] ?? "1") ?? 1
        state.sanity = max(0, state.sanity - amt)
    }
}

public func registerTakeDamage(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("take-damage") { state, params in
        let amt = Int(params["by"] ?? "1") ?? 1
        state.health = max(0, state.health - amt)
    }
}

public func registerGainItem(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("gain-item") { state, params in
        if let id = params["item"] { state.inventory.insert(id) }
    }
}