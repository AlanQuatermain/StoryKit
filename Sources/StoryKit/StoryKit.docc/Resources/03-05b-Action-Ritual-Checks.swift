import StoryKit

public func ritualChecks(_ state: HauntedState, order: [String]) -> Bool {
    let required = ["candle", "tome", "dagger"]
    guard state.has("black_candle"), state.has("forbidden_tome"), state.has("silver_dagger") else { return false }
    return order.map { $0.lowercased() } == required
}

