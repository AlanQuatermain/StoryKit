import Foundation
import Testing
import StoryKit

@Suite("CoreRegistries")
struct CoreRegistryTests {
    struct State: StoryState { var currentNode: NodeID; var value: Int = 0 }

    @Test("Predicate and effect")
    func predicateAndEffect() throws {
        var preds = PredicateRegistry<State>()
        preds.register("isZero") { state, _ in state.value == 0 }
        var effs = EffectRegistry<State>()
        effs.register("inc") { state, _ in state.value += 1 }

        var s = State(currentNode: NodeID(rawValue: "n"))
        #expect(preds.evaluate(.init(id: "isZero"), state: s))
        effs.apply([.init(id: "inc")], state: &s)
        #expect(s.value == 1)
        #expect(preds.evaluate(.init(id: "isZero"), state: s) == false)
    }

    @Test("Unknown action returns nil")
    func unknownActionReturnsNil() throws {
        let acts = ActionRegistry<State>()
        var s = State(currentNode: NodeID(rawValue: "n"))
        let res = try acts.perform("nope", state: &s, parameters: [:])
        #expect(res == nil)
    }

    @Test("Action performs and returns completed")
    func actionPerformsAndReturnsCompleted() throws {
        var acts = ActionRegistry<State>()
        acts.register("inc") { s, _ in s.value += 3; return .completed }
        var s = State(currentNode: NodeID(rawValue: "n"))
        let res = try acts.perform("inc", state: &s, parameters: [:])
        #expect(s.value == 3)
        #expect(res != nil)
    }
}
