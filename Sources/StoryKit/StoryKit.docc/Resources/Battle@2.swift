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
    }
}