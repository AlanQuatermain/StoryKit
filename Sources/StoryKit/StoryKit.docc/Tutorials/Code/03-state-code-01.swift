import StoryKit

struct PlayerState: StoryState, Codable, Sendable {
    var currentNode: NodeID
    var hitPoints: Int = 10
    var sanity: Int = 12
    var inventory: [String] = []
}

