import Foundation
import StoryKit

public struct Entity {
    public var id: String
    public var name: String
    public var hp: Int
    public var attack: ClosedRange<Int>
}

public let boneServant = Entity(id: "bone_servant", name: "Bone Servant", hp: 8, attack: 1...4)

public func registerBattle(into actions: inout ActionRegistry<HauntedState>) {
    actions.register("melee-round") { state, params in
        var enemy = boneServant
        if let hpStr = params["enemyHP"], let hp = Int(hpStr) { enemy.hp = hp }

        // flee check
        if params["attempt"] == "flee" {
            let fleeRoll = Int.random(in: 1...20)
            if fleeRoll <= 10 { // succeeds
                state.setFlag("fled", to: true)
                return .completed
            } else {
                // enemy retaliates on failed flee
                let dmg = Int.random(in: enemy.attack)
                state.health = max(0, state.health - dmg)
                return .requiresUserInput(hint: "Flee failed. Took \(dmg) damage.")
            }
        }

        // player attacks
        let playerHit = Int.random(in: 1...20) <= 12
        if playerHit {
            let dmg = Int.random(in: 2...5)
            state.setFlag("enemyTookDamage", to: true)
            // persist enemy status at call site in a real game
            return .requiresUserInput(hint: "You strike for \(dmg) damage.")
        } else {
            // enemy retaliates
            let dmg = Int.random(in: enemy.attack)
            state.health = max(0, state.health - dmg)
            return .requiresUserInput(hint: "Miss! The \(enemy.name) hits for \(dmg).")
        }
    }
}

