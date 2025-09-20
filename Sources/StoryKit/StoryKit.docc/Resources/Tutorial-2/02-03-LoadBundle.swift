import Foundation
import StoryKit

public func loadStory(from bundlePath: String) throws -> Story {
    let url = URL(fileURLWithPath: bundlePath)
    let layout = StoryBundleLayout(root: url)
    return try StoryBundleLoader().load(from: layout)
}

