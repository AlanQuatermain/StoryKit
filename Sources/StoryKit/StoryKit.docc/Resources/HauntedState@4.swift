import StoryKit

public struct Ritual: Codable, Sendable {
    public var candleLit: Bool = false
    public var tomeRead: Bool = false
    public var sacrificeMade: Bool = false
    
    public var isComplete: Bool {
        candleLit && tomeRead && sacrificeMade
    }
    
    public var nextStep: String? {
        if !candleLit { return "light_candle" }
        if !tomeRead { return "read_tome" }
        if !sacrificeMade { return "make_sacrifice" }
        return nil
    }
}

public struct HauntedState: StoryState, Codable, Sendable {
    public var currentNode: NodeID
    public var health: Int = 10
    public var sanity: Int = 10
    public var inventory: Set<String> = []
    public var flags: Set<String> = []
    public var ritual: Ritual = Ritual()
    public init(start: NodeID) { self.currentNode = start }

    public mutating func gain(_ item: String) { inventory.insert(item) }
    public func has(_ item: String) -> Bool { inventory.contains(item) }
    public mutating func setFlag(_ id: String, to value: Bool) {
        if value { flags.insert(id) } else { flags.remove(id) }
    }
}