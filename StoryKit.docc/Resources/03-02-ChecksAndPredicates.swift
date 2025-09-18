import Foundation
import StoryKit

public func registerPredicates(into registry: inout PredicateRegistry<HauntedState>) {
    registry.register("has-item") { state, params in
        guard let item = params["item"] else { return false }
        return state.inventory.contains(item)
    }
    registry.register("stat-at-least") { state, params in
        guard let stat = params["stat"], let minStr = params["min"], let min = Int(minStr) else { return false }
        let value: Int
        switch stat { case "health": value = state.health; case "sanity": value = state.sanity; default: return false }
        return value >= min
    }
}

public func rollD20() -> Int { Int.random(in: 1...20) }

public func check(_ stat: String, under value: Int) -> Bool {
    let roll = rollD20()
    return roll <= value
}

