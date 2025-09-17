import Foundation
import Core

/// An actor that executes story flow for a given story and app-defined state.
///
/// The engine evaluates predicates for available choices, applies effects on selection,
/// transitions to destination nodes, applies on-enter effects, and invokes an optional autosave handler.
public actor StoryEngine<State: StoryState> {
    /// The story being executed.
    public let story: Story
    /// The current state, isolated to the engine actor.
    public private(set) var state: State

    /// Registry of predicate closures used to gate choices.
    public var predicateRegistry: PredicateRegistry<State>
    /// Registry of effect closures used to mutate state.
    public var effectRegistry: EffectRegistry<State>
    /// Registry of action closures for richer interactions.
    public var actionRegistry: ActionRegistry<State>
    /// An optional autosave handler invoked after transitions and actions.
    public typealias AutoSaveHandler = @Sendable (State) async throws -> Void
    private let autosave: AutoSaveHandler?

    /// Creates a new engine instance.
    /// - Parameters:
    ///   - story: The story graph to run.
    ///   - initialState: The initial app-defined state.
    ///   - predicateRegistry: Predicates for gating choices.
    ///   - effectRegistry: Effects applied on select and enter.
    ///   - actionRegistry: Actions for custom interactions.
    ///   - autosave: Optional handler called after transitions/actions.
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

    /// Returns the current node, if present.
    public func currentNode() -> Node? {
        story.nodes[state.currentNode]
    }

    /// Returns choices that are currently available based on predicate evaluation.
    public func availableChoices() -> [Choice] {
        guard let node = story.nodes[state.currentNode] else { return [] }
        return node.choices.filter { choice in
            choice.predicates.allSatisfy { predicateRegistry.evaluate($0, state: state) }
        }
    }

    @discardableResult
    /// Selects a choice, applies effects, transitions to the destination, applies on-enter effects, and triggers autosave.
    /// - Parameter choiceID: The identifier of the selected choice.
    /// - Returns: The identifier of the new current node.
    /// - Throws: ``EngineError`` if the selection is invalid or blocked.
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

    /// Applies the on-enter effects for the current node, if any.
    public func applyOnEnterEffectsIfAny() {
        guard let node = story.nodes[state.currentNode] else { return }
        effectRegistry.apply(node.onEnter, state: &state)
    }

    // Perform a named action (client-registered) then autosave.
    @discardableResult
    /// Performs a registered action with parameters and triggers autosave.
    /// - Parameters:
    ///   - id: The action identifier.
    ///   - parameters: String parameters for the action.
    /// - Returns: The outcome of the action, if any.
    /// - Throws: Any error thrown by the action.
    public func performAction(id: String, parameters: [String: String] = [:]) async throws -> ActionOutcome? {
        let outcome = try actionRegistry.perform(id, state: &state, parameters: parameters)
        if let autosave {
            try await autosave(state)
        }
        return outcome
    }

    // Perform a globally-declared action by id (transitions to its destination and applies on-enter effects).
    @discardableResult
    public func performGlobalAction(id: String) async throws -> NodeID {
        guard let ga = story.globals?.globalActions[id] else { throw EngineError.unknownGlobalAction }
        state.currentNode = ga.destination
        if let dest = story.nodes[state.currentNode] {
            effectRegistry.apply(dest.onEnter, state: &state)
        }
        if let autosave { try await autosave(state) }
        return state.currentNode
    }
}

/// Errors thrown by the story engine for invalid or blocked operations.
public enum EngineError: Error, Equatable {
    case unknownNode
    case unknownChoice
    case choiceBlocked
    case unknownGlobalAction
}
