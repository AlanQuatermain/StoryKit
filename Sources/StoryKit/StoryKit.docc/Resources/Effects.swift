import StoryKit

public func registerLoseSanity(into effs: inout EffectRegistry<HauntedState>) {
    effs.register("lose-sanity") { state, params in
        let amt = Int(params["by"] ?? "1") ?? 1
        state.sanity = max(0, state.sanity - amt)
    }
}