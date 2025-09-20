import StoryKit

extension Ritual {
    static func registerActions(into acts: inout ActionRegistry<HauntedState>) {
        acts.register("light_candle") { state, params in
            guard state.has("black_candle") else {
                return .requiresUserInput(hint: "You need the black candle first.")
            }
            
            if state.ritual.lightCandle() {
                return .completed
            } else {
                return .requiresUserInput(hint: "The candle is already lit.")
            }
        }
        
        acts.register("read_tome") { state, params in
            guard state.has("forbidden_tome") else {
                return .requiresUserInput(hint: "You need the forbidden tome first.")
            }
            
            if state.ritual.readTome() {
                return .completed
            } else {
                return .requiresUserInput(hint: "You have already read from the tome.")
            }
        }
    }
}