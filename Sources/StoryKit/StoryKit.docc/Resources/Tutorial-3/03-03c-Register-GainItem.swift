import StoryKit

public func registerGainItem(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("gain-item") { state, params in
        if let id = params["item"] { state.inventory.insert(id) }
    }
}

