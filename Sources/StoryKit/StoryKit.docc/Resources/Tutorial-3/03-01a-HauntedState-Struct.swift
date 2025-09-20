import StoryKit

public struct HauntedState: StoryState, Codable, Sendable {
    public var currentNode: NodeID
    public init(start: NodeID) { self.currentNode = start }
}

