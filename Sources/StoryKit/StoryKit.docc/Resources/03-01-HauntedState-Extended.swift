import StoryKit

public struct HauntedState: StoryState {
    public var currentNode: NodeID
    public var health: Int
    public var sanity: Int
    public var inventory: Set<String>
    public var flags: [String: Bool]

    public init(start: NodeID) {
        self.currentNode = start
        self.health = 10
        self.sanity = 10
        self.inventory = []
        self.flags = [:]
    }

    public mutating func gain(_ item: String) { inventory.insert(item) }
    public func has(_ item: String) -> Bool { inventory.contains(item) }
    public mutating func setFlag(_ key: String, to value: Bool) { flags[key] = value }
    public func flag(_ key: String) -> Bool { flags[key] ?? false }
}

