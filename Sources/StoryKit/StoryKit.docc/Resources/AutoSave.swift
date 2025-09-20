import StoryKit

public func makeAutoSave(storyID: String) -> @Sendable (HauntedState) async throws -> Void {
    let provider = JSONFileSaveProvider(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
    return makeAutoSaveHandler(storyID: storyID, provider: provider)
}