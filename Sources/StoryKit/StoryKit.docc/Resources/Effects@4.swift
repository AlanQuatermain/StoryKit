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

public func registerSetFlag(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("set-flag") { state, params in
        guard let id = params["id"], let val = params["value"] else { return }
        if (val as NSString).boolValue { state.flags.insert(id) } else { state.flags.remove(id) }
    }
}

public func registerSpawn(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("spawn") { state, params in
        guard let entity = params["entity"] else { return }
        // Set flag to track spawned entity for combat system
        state.setFlag("spawned_\(entity)", to: true)
        // Could also set current enemy type for battle system
        state.setFlag("current_enemy", to: true)
    }
}