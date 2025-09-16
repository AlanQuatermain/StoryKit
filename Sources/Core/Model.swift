import Foundation

public struct NodeID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct ChoiceID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct TextRef: Hashable, Codable, Sendable {
    /// Relative path to a Markdown file within a story source or bundle.
    public var file: String
    /// Section identifier within the Markdown file, allowing multiple nodes per file.
    public var section: String
    public init(file: String, section: String) {
        self.file = file
        self.section = section
    }
}

public struct Choice: Codable, Sendable, Identifiable, Hashable {
    public var id: ChoiceID
    public var title: String?
    public var titleKey: String?
    public var destination: NodeID
    /// Optional predicate descriptors for gating visibility/availability.
    public var predicates: [PredicateDescriptor]
    /// Optional effects applied when this choice is selected.
    public var effects: [EffectDescriptor]

    public init(
        id: ChoiceID,
        title: String? = nil,
        titleKey: String? = nil,
        destination: NodeID,
        predicates: [PredicateDescriptor] = [],
        effects: [EffectDescriptor] = []
    ) {
        self.id = id
        self.title = title
        self.titleKey = titleKey
        self.destination = destination
        self.predicates = predicates
        self.effects = effects
    }
}

public struct Node: Codable, Sendable, Identifiable, Hashable {
    public var id: NodeID
    public var text: TextRef
    public var tags: [String]
    public var onEnter: [EffectDescriptor]
    public var choices: [Choice]

    public init(
        id: NodeID,
        text: TextRef,
        tags: [String] = [],
        onEnter: [EffectDescriptor] = [],
        choices: [Choice] = []
    ) {
        self.id = id
        self.text = text
        self.tags = tags
        self.onEnter = onEnter
        self.choices = choices
    }
}

public struct Story: Codable, Sendable {
    public struct Metadata: Codable, Sendable {
        public var id: String
        public var title: String
        public var version: Int
        public init(id: String, title: String, version: Int = 1) {
            self.id = id
            self.title = title
            self.version = version
        }
    }

    public var metadata: Metadata
    public var start: NodeID
    public var nodes: [NodeID: Node]

    public init(metadata: Metadata, start: NodeID, nodes: [NodeID: Node]) {
        self.metadata = metadata
        self.start = start
        self.nodes = nodes
    }
}

// MARK: - Predicate/Effect Descriptors (data-only)

public struct PredicateDescriptor: Codable, Sendable, Hashable {
    public var id: String
    /// Parameters are opaque to the engine; clients interpret them.
    public var parameters: [String: String]
    public init(id: String, parameters: [String: String] = [:]) {
        self.id = id
        self.parameters = parameters
    }
}

public struct EffectDescriptor: Codable, Sendable, Hashable {
    public var id: String
    public var parameters: [String: String]
    public init(id: String, parameters: [String: String] = [:]) {
        self.id = id
        self.parameters = parameters
    }
}

// MARK: - State & Registries

public protocol StoryState: Codable, Sendable {
    var currentNode: NodeID { get set }
}

public typealias Predicate<State> = @Sendable (_ state: State, _ parameters: [String: String]) -> Bool
public typealias Effect<State> = @Sendable (_ state: inout State, _ parameters: [String: String]) -> Void
public typealias Action<State> = @Sendable (_ state: inout State, _ parameters: [String: String]) async throws -> ActionOutcome

public enum ActionOutcome: Sendable {
    case completed
    case requiresUserInput(hint: String)
}

public struct PredicateRegistry<State>: Sendable {
    private var map: [String: Predicate<State>] = [:]
    public init() {}
    public mutating func register(_ id: String, _ predicate: @escaping @Sendable Predicate<State>) {
        map[id] = predicate
    }
    public func evaluate(_ descriptor: PredicateDescriptor, state: State) -> Bool {
        guard let p = map[descriptor.id] else { return false }
        return p(state, descriptor.parameters)
    }
}

public struct EffectRegistry<State>: Sendable {
    private var map: [String: Effect<State>] = [:]
    public init() {}
    public mutating func register(_ id: String, _ effect: @escaping @Sendable Effect<State>) {
        map[id] = effect
    }
    public func apply(_ descriptors: [EffectDescriptor], state: inout State) {
        for d in descriptors {
            if let e = map[d.id] {
                e(&state, d.parameters)
            }
        }
    }
}

public struct ActionRegistry<State>: Sendable {
    private var map: [String: Action<State>] = [:]
    public init() {}
    public mutating func register(_ id: String, _ action: @escaping @Sendable Action<State>) {
        map[id] = action
    }
    public func perform(_ id: String, state: inout State, parameters: [String: String]) async throws -> ActionOutcome? {
        guard let a = map[id] else { return nil }
        return try await a(&state, parameters)
    }
}
