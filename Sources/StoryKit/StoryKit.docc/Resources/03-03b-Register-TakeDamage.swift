import StoryKit

public func registerTakeDamage(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("take-damage") { state, params in
        let amt = Int(params["by"] ?? "1") ?? 1
        state.health = max(0, state.health - amt)
    }
}

