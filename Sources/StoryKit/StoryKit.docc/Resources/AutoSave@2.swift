import StoryKit

public func makeAutoSave(storyID: String) -> @Sendable (HauntedState) async throws -> Void {
    let provider = JSONFileSaveProvider(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
    return makeAutoSaveHandler(storyID: storyID, provider: provider)
}

func makeEngine(story: Story) -> StoryEngine<HauntedState> {
    var preds = PredicateRegistry<HauntedState>()
    var effs = EffectRegistry<HauntedState>()
    var acts = ActionRegistry<HauntedState>()
    let autosave = try? makeAutoSave(storyID: story.metadata.id)
    return StoryEngine(
        story: story,
        initialState: HauntedState(start: story.start),
        predicateRegistry: preds,
        effectRegistry: effs,
        actionRegistry: acts,
        autosave: autosave
    )
}