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
    addStatAtLeast(to: &preds)
    addRitualPredicates(to: &preds)
    return preds
}

public func addStatAtLeast(to preds: inout PredicateRegistry<HauntedState>) {
    preds.register("stat-at-least") { state, params in
        guard let key = params["stat"], let minStr = params["min"], let min = Int(minStr) else { return false }
        switch key {
        case "health": return state.health >= min
        case "sanity": return state.sanity >= min
        default: return false
        }
    }
}

public func addRitualPredicates(to preds: inout PredicateRegistry<HauntedState>) {
    preds.register("ritual-candle-lit") { state, params in
        return state.ritual.candleLit
    }
    
    preds.register("ritual-tome-read") { state, params in
        return state.ritual.tomeRead
    }
    
    preds.register("ritual-sacrifice-made") { state, params in
        return state.ritual.sacrificeMade
    }
}