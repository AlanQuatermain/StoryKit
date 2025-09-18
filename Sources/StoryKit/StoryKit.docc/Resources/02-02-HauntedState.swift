import StoryKit

public struct HauntedState: StoryState {
    public var currentNode: NodeID
    public init(start: NodeID) { self.currentNode = start }
}

