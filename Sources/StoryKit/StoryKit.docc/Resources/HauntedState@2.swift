import StoryKit

public struct HauntedState: StoryState, Codable, Sendable {
    public var currentNode: NodeID
    public var health: Int = 10
    public var sanity: Int = 10
    public var inventory: Set<String> = []
    public var flags: Set<String> = []
    public init(start: NodeID) { self.currentNode = start }
}