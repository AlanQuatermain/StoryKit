import Foundation

/// A strongly-typed identifier for a story node.
public struct NodeID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// A strongly-typed identifier for a choice within a node.
public struct ChoiceID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// A reference to prose stored in Markdown.
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

/// A labeled edge to a destination node, optionally gated by predicates and carrying effects.
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

/// A node in the story graph containing text and outgoing choices.
public struct Node: Codable, Sendable, Identifiable, Hashable {
    public var id: NodeID
    public var text: TextRef
    public var tags: [String]
    public var onEnter: [EffectDescriptor]
    public var choices: [Choice]
    /// Declarative list of actors present at this node (data-only; no mechanics).
    public var actors: [ActorDescriptor]

    public init(
        id: NodeID,
        text: TextRef,
        tags: [String] = [],
        onEnter: [EffectDescriptor] = [],
        choices: [Choice] = [],
        actors: [ActorDescriptor] = []
    ) {
        self.id = id
        self.text = text
        self.tags = tags
        self.onEnter = onEnter
        self.choices = choices
        self.actors = actors
    }

    private enum CodingKeys: String, CodingKey { case id, text, tags, onEnter, choices, actors }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(NodeID.self, forKey: .id)
        self.text = try c.decode(TextRef.self, forKey: .text)
        self.tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        self.onEnter = (try? c.decode([EffectDescriptor].self, forKey: .onEnter)) ?? []
        self.choices = (try? c.decode([Choice].self, forKey: .choices)) ?? []
        self.actors = (try? c.decode([ActorDescriptor].self, forKey: .actors)) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        if !tags.isEmpty { try c.encode(tags, forKey: .tags) } else { try c.encode([String](), forKey: .tags) }
        if !onEnter.isEmpty { try c.encode(onEnter, forKey: .onEnter) } else { try c.encode([EffectDescriptor](), forKey: .onEnter) }
        try c.encode(choices, forKey: .choices)
        if !actors.isEmpty { try c.encode(actors, forKey: .actors) } else { try c.encode([ActorDescriptor](), forKey: .actors) }
    }
}

/// A complete story graph plus metadata and a starting node.
public struct Story: Codable, Sendable {
    /// Human-readable and versioning information for a story.
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

    /// Descriptive metadata for the story.
    public var metadata: Metadata
    /// The node where the story begins.
    public var start: NodeID
    /// All nodes in the story graph keyed by id.
    public var nodes: [NodeID: Node]
    /// Optional canonical entity catalog for referencing inhabitants (data-only; no mechanics).
    public var entities: [String: EntityDescriptor]
    /// Optional globals such as globally-addressable actions.
    public var globals: Globals?

    public init(metadata: Metadata, start: NodeID, nodes: [NodeID: Node], entities: [String: EntityDescriptor] = [:], globals: Globals? = nil) {
        self.metadata = metadata
        self.start = start
        self.nodes = nodes
        self.entities = entities
        self.globals = globals
    }
    private enum CodingKeys: String, CodingKey { case metadata, start, nodes, entities, globals }

    /// Decodes a story from a JSON object where `nodes` is a string-keyed dictionary.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.metadata = try c.decode(Metadata.self, forKey: .metadata)
        self.start = try c.decode(NodeID.self, forKey: .start)
        // Decode nodes from a string-keyed dictionary for authoring convenience
        let raw = try c.decode([String: Node].self, forKey: .nodes)
        var mapped: [NodeID: Node] = [:]
        for (k, v) in raw { mapped[NodeID(rawValue: k)] = v }
        self.nodes = mapped
        self.entities = (try? c.decode([String: EntityDescriptor].self, forKey: .entities)) ?? [:]
        self.globals = try? c.decode(Globals.self, forKey: .globals)
    }

    /// Encodes a story as a JSON object where `nodes` is a string-keyed dictionary.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(metadata, forKey: .metadata)
        try c.encode(start, forKey: .start)
        let raw = Dictionary(uniqueKeysWithValues: nodes.map { ($0.key.rawValue, $0.value) })
        try c.encode(raw, forKey: .nodes)
        if !entities.isEmpty { try c.encode(entities, forKey: .entities) }
        if let globals { try c.encode(globals, forKey: .globals) }
    }
}

// MARK: - Predicate/Effect Descriptors (data-only)

/// A data-only predicate reference that binds to host logic by id.
public struct PredicateDescriptor: Codable, Sendable, Hashable {
    public var id: String
    /// Parameters are opaque to the engine; clients interpret them.
    public var parameters: [String: String]
    public init(id: String, parameters: [String: String] = [:]) {
        self.id = id
        self.parameters = parameters
    }
}

/// A data-only effect reference that binds to host logic by id.
public struct EffectDescriptor: Codable, Sendable, Hashable {
    public var id: String
    public var parameters: [String: String]
    public init(id: String, parameters: [String: String] = [:]) {
        self.id = id
        self.parameters = parameters
    }
}

// MARK: - Entities, Actors, and Globals (data-only)

/// Describes a reusable entity authors can reference (no mechanics).
public struct EntityDescriptor: Codable, Sendable, Hashable {
    public var name: String?
    public var nameKey: String?
    public var tags: [String]
    public var assetKey: String?
    public init(name: String? = nil, nameKey: String? = nil, tags: [String] = [], assetKey: String? = nil) {
        self.name = name
        self.nameKey = nameKey
        self.tags = tags
        self.assetKey = assetKey
    }
    private enum CodingKeys: String, CodingKey { case name, nameKey, tags, assetKey }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.nameKey = try c.decodeIfPresent(String.self, forKey: .nameKey)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.assetKey = try c.decodeIfPresent(String.self, forKey: .assetKey)
    }
}

/// Declares an actor present at a node by id, optionally referencing a canonical entity.
public struct ActorDescriptor: Codable, Sendable, Hashable, Identifiable {
    /// Unique within the node.
    public var id: String
    /// Reference to a top-level entity id (in `Story.entities`).
    public var ref: String?
    /// Inline override for display label.
    public var name: String?
    public var nameKey: String?
    public var tags: [String]
    public var faction: String?
    public init(id: String, ref: String? = nil, name: String? = nil, nameKey: String? = nil, tags: [String] = [], faction: String? = nil) {
        self.id = id
        self.ref = ref
        self.name = name
        self.nameKey = nameKey
        self.tags = tags
        self.faction = faction
    }
    private enum CodingKeys: String, CodingKey { case id, ref, name, nameKey, tags, faction }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.ref = try c.decodeIfPresent(String.self, forKey: .ref)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.nameKey = try c.decodeIfPresent(String.self, forKey: .nameKey)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.faction = try c.decodeIfPresent(String.self, forKey: .faction)
    }
}

/// Global configuration for a story.
public struct Globals: Codable, Sendable {
    public var globalActions: [String: GlobalAction]
    public init(globalActions: [String: GlobalAction] = [:]) { self.globalActions = globalActions }
}

/// A globally addressable action mapping to a destination node (data-only).
public struct GlobalAction: Codable, Sendable, Hashable {
    public var title: String?
    public var titleKey: String?
    public var destination: NodeID
    public init(title: String? = nil, titleKey: String? = nil, destination: NodeID) {
        self.title = title
        self.titleKey = titleKey
        self.destination = destination
    }
}

// MARK: - State & Registries

/// App-defined, codable story state used by the engine.
public protocol StoryState: Codable, Sendable {
    var currentNode: NodeID { get set }
}

/// A predicate closure used to gate choice availability.
public typealias Predicate<State> = @Sendable (_ state: State, _ parameters: [String: String]) -> Bool
/// An effect closure used to mutate state when a choice is taken or a node is entered.
public typealias Effect<State> = @Sendable (_ state: inout State, _ parameters: [String: String]) -> Void
/// An action closure used for richer interactions that may throw and return an outcome.
public typealias Action<State> = @Sendable (_ state: inout State, _ parameters: [String: String]) throws -> ActionOutcome

/// Outcome of a performed action.
public enum ActionOutcome: Sendable {
    case completed
    case requiresUserInput(hint: String)
}

/// Registry that maps predicate ids to evaluation closures.
public struct PredicateRegistry<State>: Sendable {
    private var map: [String: Predicate<State>] = [:]
    public init() {}
    /// Registers a predicate closure for an identifier.
    public mutating func register(_ id: String, _ predicate: @escaping @Sendable Predicate<State>) {
        map[id] = predicate
    }
    /// Evaluates a descriptor against the current state.
    public func evaluate(_ descriptor: PredicateDescriptor, state: State) -> Bool {
        guard let p = map[descriptor.id] else { return false }
        return p(state, descriptor.parameters)
    }
}

/// Registry that maps effect ids to mutation closures.
public struct EffectRegistry<State>: Sendable {
    private var map: [String: Effect<State>] = [:]
    public init() {}
    /// Registers an effect closure for an identifier.
    public mutating func register(_ id: String, _ effect: @escaping @Sendable Effect<State>) {
        map[id] = effect
    }
    /// Applies a sequence of effect descriptors to the given state in order.
    public func apply(_ descriptors: [EffectDescriptor], state: inout State) {
        for d in descriptors {
            if let e = map[d.id] {
                e(&state, d.parameters)
            }
        }
    }
}

/// Registry that maps action ids to action closures.
public struct ActionRegistry<State>: Sendable {
    private var map: [String: Action<State>] = [:]
    public init() {}
    /// Registers an action closure for an identifier.
    public mutating func register(_ id: String, _ action: @escaping @Sendable Action<State>) {
        map[id] = action
    }
    /// Performs an action for the identifier if present and returns its outcome.
    public func perform(_ id: String, state: inout State, parameters: [String: String]) throws -> ActionOutcome? {
        guard let a = map[id] else { return nil }
        return try a(&state, parameters)
    }
}
