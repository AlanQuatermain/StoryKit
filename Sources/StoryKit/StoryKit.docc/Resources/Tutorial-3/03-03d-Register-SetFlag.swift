import StoryKit

public func registerSetFlag(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("set-flag") { state, params in
        guard let id = params["id"], let val = params["value"] else { return }
        if (val as NSString).boolValue { state.flags.insert(id) } else { state.flags.remove(id) }
    }
}

