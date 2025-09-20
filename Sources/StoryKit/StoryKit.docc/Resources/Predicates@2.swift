import Foundation
import StoryKit

public func rollD20() -> Int { Int.random(in: 1...20) }
public func checkUnder(_ threshold: Int, roll: Int = rollD20()) -> Bool { roll <= threshold }

public func makePredicates() -> PredicateRegistry<HauntedState> {
    var preds = PredicateRegistry<HauntedState>()
    preds.register("has-item") { state, params in
        guard let id = params["item"] else { return false }
        return state.inventory.contains(id)
    }
    return preds
}