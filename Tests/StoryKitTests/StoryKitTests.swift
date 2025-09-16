import Testing
import Core
import Engine

private struct SimpleState: StoryState {
    var currentNode: NodeID
}

@Suite("Engine")
struct EngineTests {
    @Test
    func engineBasicFlow() async throws {
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

    @Test
    func choiceGatingAndErrors() async throws {
    let a = NodeID(rawValue: "a")
    let b = NodeID(rawValue: "b")
    let blockedChoiceID = ChoiceID(rawValue: "blocked")
    let nodes: [NodeID: Node] = [
        a: Node(
            id: a,
            text: TextRef(file: "texts/main.md", section: "a"),
            choices: [
                Choice(id: blockedChoiceID, title: "Nope", destination: b, predicates: [PredicateDescriptor(id: "blocked")])
            ]
        ),
        b: Node(id: b, text: TextRef(file: "texts/main.md", section: "b"), choices: [])
    ]
    let story = Story(metadata: .init(id: "s", title: "S"), start: a, nodes: nodes)
    var preds = PredicateRegistry<SimpleState>()
    preds.register("blocked") { _, _ in false }
    let engine = StoryEngine(story: story, initialState: SimpleState(currentNode: a), predicateRegistry: preds)
    // Available choices should be empty due to predicate false
    let choices = await engine.availableChoices()
    #expect(choices.isEmpty)
    // Selecting should throw
    await #expect(throws: EngineError.choiceBlocked) {
        _ = try await engine.select(choiceID: blockedChoiceID)
    }
    }

    @Test
    func autosaveAndOnEnterEffects() async throws {
        struct S: StoryState { var currentNode: NodeID; var count: Int = 0 }
        let a = NodeID(rawValue: "a")
        let b = NodeID(rawValue: "b")
        let nodes: [NodeID: Node] = [
            a: Node(id: a, text: TextRef(file: "t.md", section: "a"), choices: [Choice(id: ChoiceID(rawValue: "go"), title: "Go", destination: b)]),
            b: Node(id: b, text: TextRef(file: "t.md", section: "b"), onEnter: [EffectDescriptor(id: "inc")], choices: [])
        ]
        let story = Story(metadata: .init(id: "id", title: "T"), start: a, nodes: nodes)
        var effs = EffectRegistry<S>()
        effs.register("inc") { s, _ in s.count += 1 }
        actor Sink { var items: [S] = []; func append(_ s: S) { items.append(s) } }
        let sink = Sink()
        let autosave: (@Sendable (S) async throws -> Void) = { s in await sink.append(s) }
        let engine = StoryEngine(story: story, initialState: S(currentNode: a), effectRegistry: effs, autosave: autosave)
        _ = try await engine.select(choiceID: ChoiceID(rawValue: "go"))
        // Verify autosave captured state and onEnter effect applied
        #expect(await sink.items.count == 1)
        #expect(await sink.items.first?.count == 1)
    }

    @Test
    func performActionAutosave() async throws {
        struct S: StoryState { var currentNode: NodeID; var count: Int = 0 }
        let a = NodeID(rawValue: "a")
        let story = Story(metadata: .init(id: "id", title: "T"), start: a, nodes: [a: Node(id: a, text: TextRef(file: "t.md", section: "a"), choices: [])])
        var acts = ActionRegistry<S>()
        acts.register("inc2") { s, _ in s.count += 2; return .completed }
        actor Sink { var items: [S] = []; func append(_ s: S) { items.append(s) } }
        let sink = Sink()
        let autosave: (@Sendable (S) async throws -> Void) = { s in await sink.append(s) }
        let engine = StoryEngine(story: story, initialState: S(currentNode: a), actionRegistry: acts, autosave: autosave)
        _ = try await engine.performAction(id: "inc2")
        #expect(await sink.items.count == 1)
        #expect(await sink.items.first?.count == 2)
    }
}
