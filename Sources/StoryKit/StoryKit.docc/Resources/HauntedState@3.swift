import StoryKit

public struct HauntedState: StoryState, Codable, Sendable {
    public var currentNode: NodeID
    public var health: Int = 10
    public var sanity: Int = 10
    public var inventory: Set<String> = []
    public var flags: Set<String> = []
    public init(start: NodeID) { self.currentNode = start }

    public mutating func gain(_ item: String) { inventory.insert(item) }
    public func has(_ item: String) -> Bool { inventory.contains(item) }
    public mutating func setFlag(_ id: String, to value: Bool) {
        if value { flags.insert(id) } else { flags.remove(id) }
    }
}