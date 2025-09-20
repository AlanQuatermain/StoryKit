import Foundation
import StoryKit

public func makeAutosave(storyID: String) -> (@Sendable (HauntedState) async throws -> Void) {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("HauntedSaves")
    let provider = JSONFileSaveProvider<HauntedState>(directory: dir)
    return makeAutoSaveHandler(storyID: storyID, slot: "autosave", provider: provider)
}

