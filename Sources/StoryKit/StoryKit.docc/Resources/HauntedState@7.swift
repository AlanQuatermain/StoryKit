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
    
    public mutating func lightCandle() -> Bool {
        guard !candleLit else { return false }
        candleLit = true
        return true
    }
    
    public mutating func readTome() -> Bool {
        guard !tomeRead else { return false }
        tomeRead = true
        return true
    }
}

public struct BoneServant: Codable, Sendable {
    public var isActive: Bool = false
    public var turnsUntilArrival: Int = 3
    public var currentRoom: String = "ritual_chamber"
    
    public mutating func activate() {
        isActive = true
        turnsUntilArrival = 3
    }
    
    public mutating func advance() {
        if isActive && turnsUntilArrival > 0 {
            turnsUntilArrival -= 1
        }
    }
    
    public var hasArrived: Bool { isActive && turnsUntilArrival <= 0 }
}

public struct HauntedState: StoryState, Codable, Sendable {
    public var currentNode: NodeID
    public var health: Int = 10
    public var sanity: Int = 10
    public var inventory: Set<String> = []
    public var flags: Set<String> = []
    public var ritual: Ritual = Ritual()
    public var boneServant: BoneServant = BoneServant()
    public init(start: NodeID) { self.currentNode = start }

    public mutating func gain(_ item: String) { inventory.insert(item) }
    public func has(_ item: String) -> Bool { inventory.contains(item) }
    public mutating func setFlag(_ id: String, to value: Bool) {
        if value { flags.insert(id) } else { flags.remove(id) }
    }
}