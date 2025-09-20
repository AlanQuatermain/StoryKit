import StoryKit

extension BoneServant {
    static func registerActions(into acts: inout ActionRegistry<HauntedState>) {
        acts.register("check_pursuit") { state, params in
            if state.boneServant.hasArrived {
                return .requiresUserInput(hint: "The bone servant has found you!")
            } else {
                state.boneServant.advance()
                return .completed
            }
        }
        
        acts.register("flee_servant") { state, params in
            let dex = Int(params["dex"] ?? "12") ?? 12
            if checkUnder(dex) {
                state.boneServant = BoneServant() // Reset the servant
                return .completed
            } else {
                state.sanity = max(0, state.sanity - 2)
                return .requiresUserInput(hint: "You failed to escape!")
            }
        }
    }
}