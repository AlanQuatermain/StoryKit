import StoryKit
import Foundation

func makeEngine(story: Story) -> StoryEngine<PlayerState> {
    let provider = JSONFileSaveProvider<PlayerState>(directory: URL(fileURLWithPath: "Saves"))
    let autosave = makeAutoSaveHandler(storyID: story.metadata.id, slot: "default", provider: provider)
    var (preds, effs, acts) = makeRegistries()
    registerActions(into: &acts)
    return StoryEngine(
        story: story,
        initialState: PlayerState(currentNode: story.start),
        predicateRegistry: preds,
        effectRegistry: effs,
        actionRegistry: acts,
        autosave: autosave
    )
}

