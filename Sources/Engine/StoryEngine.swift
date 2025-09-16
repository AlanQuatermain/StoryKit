import Foundation
import Core

public actor StoryEngine<State: StoryState> {
    public let story: Story
    public private(set) var state: State

    public var predicateRegistry: PredicateRegistry<State>
    public var effectRegistry: EffectRegistry<State>
    public var actionRegistry: ActionRegistry<State>
    public typealias AutoSaveHandler = @Sendable (State) async throws -> Void
    private let autosave: AutoSaveHandler?

    public init(
        story: Story,
        initialState: State,
        predicateRegistry: PredicateRegistry<State> = .init(),
        effectRegistry: EffectRegistry<State> = .init(),
        actionRegistry: ActionRegistry<State> = .init(),
        autosave: AutoSaveHandler? = nil
    ) {
        self.story = story
        self.state = initialState
        self.predicateRegistry = predicateRegistry
        self.effectRegistry = effectRegistry
        self.actionRegistry = actionRegistry
        self.autosave = autosave
    }

    public func currentNode() -> Node? {
        story.nodes[state.currentNode]
    }

    public func availableChoices() -> [Choice] {
        guard let node = story.nodes[state.currentNode] else { return [] }
        return node.choices.filter { choice in
            choice.predicates.allSatisfy { predicateRegistry.evaluate($0, state: state) }
        }
    }

    @discardableResult
    public func select(choiceID: ChoiceID) async throws -> NodeID {
        guard let node = story.nodes[state.currentNode] else { throw EngineError.unknownNode }
        guard let choice = node.choices.first(where: { $0.id == choiceID }) else { throw EngineError.unknownChoice }
        let allowed = choice.predicates.allSatisfy { predicateRegistry.evaluate($0, state: state) }
        guard allowed else { throw EngineError.choiceBlocked }
        effectRegistry.apply(choice.effects, state: &state)
        state.currentNode = choice.destination
        if let dest = story.nodes[state.currentNode] {
            effectRegistry.apply(dest.onEnter, state: &state)
        }
        if let autosave {
            try await autosave(state)
        }
        return state.currentNode
    }

    public func applyOnEnterEffectsIfAny() {
        guard let node = story.nodes[state.currentNode] else { return }
        effectRegistry.apply(node.onEnter, state: &state)
    }

    // Perform a named action (client-registered) then autosave.
    @discardableResult
    public func performAction(id: String, parameters: [String: String] = [:]) async throws -> ActionOutcome? {
        let outcome = try actionRegistry.perform(id, state: &state, parameters: parameters)
        if let autosave {
            try await autosave(state)
        }
        return outcome
    }
}

public enum EngineError: Error {
    case unknownNode
    case unknownChoice
    case choiceBlocked
}
