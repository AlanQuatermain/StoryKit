import Testing
import Core
import Engine

private struct SimpleState: StoryState {
    var currentNode: NodeID
}

@Test
func engine_basic_flow() async throws {
    let start = NodeID(rawValue: "start")
    let end = NodeID(rawValue: "end")

    let nodes: [NodeID: Node] = [
        start: Node(
            id: start,
            text: TextRef(file: "texts/main.md", section: "start"),
            choices: [
                Choice(id: ChoiceID(rawValue: "c1"), title: "Go", destination: end)
            ]
        ),
        end: Node(
            id: end,
            text: TextRef(file: "texts/main.md", section: "end"),
            choices: []
        )
    ]

    let story = Story(metadata: .init(id: "s", title: "Sample"), start: start, nodes: nodes)
    let engine = StoryEngine(story: story, initialState: SimpleState(currentNode: start))

    #expect(await engine.currentNode()?.id == start)
    let choices = await engine.availableChoices()
    #expect(choices.count == 1)
    _ = try await engine.select(choiceID: ChoiceID(rawValue: "c1"))
    #expect(await engine.currentNode()?.id == end)
}


@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}
