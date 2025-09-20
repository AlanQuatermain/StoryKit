import Foundation
import Testing
@testable import StoryKit
import StoryKit

@Suite("Validation")
struct ValidationTests {
    @Test("Validator severity checks")
    func validatorSeverityChecks() async throws {
        let a = NodeID(rawValue: "A")
        let b = NodeID(rawValue: "B")
        let c = NodeID(rawValue: "C")
        let d = NodeID(rawValue: "D")
        let nodes: [NodeID: Node] = [
            a: Node(id: a, text: TextRef(file: "f.md", section: "a"), choices: [
                Choice(id: ChoiceID(rawValue: "toB"), title: "to B", destination: b),
                Choice(id: ChoiceID(rawValue: "toD"), title: "to D", destination: d)
            ]),
            b: Node(id: b, text: TextRef(file: "f.md", section: "b"), choices: [
                // Missing destination to trigger error
                Choice(id: ChoiceID(rawValue: "toMissing"), title: "to missing", destination: NodeID(rawValue: "MISSING"))
            ]),
            c: Node(id: c, text: TextRef(file: "f.md", section: "c"), choices: []), // unreachable
            d: Node(id: d, text: TextRef(file: "f.md", section: "d"), choices: []) // reachable + empty choices
        ]
        let story = Story(metadata: .init(id: "s", title: "Sample"), start: a, nodes: nodes)
        let issues = StoryValidator().validate(story: story)
        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }
        // Expect: missing destination (error), unreachable C (error), empty choices at C (warning)
        #expect(errors.contains { $0.kind == .missingDestination })
        #expect(errors.contains { $0.kind == .unreachableNode })
        #expect(warnings.contains { $0.kind == .emptyChoices })
    }

    @Test("No-exit cycle warning")
    func cycleDetectionWarning() async throws {
        // A <-> B cycle with no exit should produce a warning
        let a = NodeID(rawValue: "A")
        let b = NodeID(rawValue: "B")
        let nodes: [NodeID: Node] = [
            a: Node(id: a, text: TextRef(file: "f.md", section: "a"), choices: [Choice(id: ChoiceID(rawValue: "ab"), title: "to B", destination: b)]),
            b: Node(id: b, text: TextRef(file: "f.md", section: "b"), choices: [Choice(id: ChoiceID(rawValue: "ba"), title: "to A", destination: a)])
        ]
        let story = Story(metadata: .init(id: "s", title: "S"), start: a, nodes: nodes)
        let issues = StoryValidator().validate(story: story)
        #expect(issues.contains { $0.kind == .noExitCycle && $0.severity == .warning })
    }

    @Test("Missing start node is error")
    func missingStartNodeIsError() {
        let a = NodeID(rawValue: "A")
        // Intentionally set start to a non-existent node
        let story = Story(metadata: .init(id: "s", title: "S"), start: NodeID(rawValue: "NOPE"), nodes: [
            a: Node(id: a, text: TextRef(file: "t.md", section: "a"), choices: [])
        ])
        let issues = StoryValidator().validate(story: story)
        #expect(issues.contains { $0.kind == .missingStart && $0.severity == .error })
    }

    @Test("Duplicate choice IDs is error")
    func duplicateChoiceIdsIsError() {
        let a = NodeID(rawValue: "A")
        let c = ChoiceID(rawValue: "dup")
        let story = Story(
            metadata: .init(id: "s", title: "S"),
            start: a,
            nodes: [
                a: Node(
                    id: a,
                    text: TextRef(file: "t.md", section: "a"),
                    choices: [
                        Choice(id: c, title: "one", destination: a),
                        Choice(id: c, title: "two", destination: a)
                    ]
                )
            ]
        )
        let issues = StoryValidator().validate(story: story)
        #expect(issues.contains { $0.kind == .duplicateChoiceID && $0.severity == .error })
    }

    @Test("Node key/id mismatch warning")
    func nodeKeyIdMismatchWarning() {
        let key = NodeID(rawValue: "KEY")
        let id = NodeID(rawValue: "ID")
        let story = Story(
            metadata: .init(id: "s", title: "S"),
            start: id,
            nodes: [
                key: Node(id: id, text: TextRef(file: "t.md", section: "x"), choices: [])
            ]
        )
        let issues = StoryValidator().validate(story: story)
        #expect(issues.contains { $0.kind == .nodeKeyMismatch && $0.severity == .warning })
    }

    @Test("Orphan markdown warnings (source)")
    func orphanMarkdownWarningsFromSource() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = StorySourceLayout(root: tmp)
        let fm = FileManager.default
        try fm.createDirectory(at: source.root, withIntermediateDirectories: true)
        try fm.createDirectory(at: source.textsDir, withIntermediateDirectories: true)
        // story references only section 'used' in file f.md
        let a = NodeID(rawValue: "A")
        let story = Story(
            metadata: .init(id: "s", title: "S"),
            start: a,
            nodes: [a: Node(id: a, text: TextRef(file: "f.md", section: "used"), choices: [])]
        )
        let data = try JSONEncoder().encode(story)
        try data.write(to: source.storyJSON)
        // f.md contains an extra unused section
        try "=== node: used ===\nU\n=== node: extra ===\nE\n".write(to: source.textsDir.appendingPathComponent("f.md"), atomically: true, encoding: .utf8)
        // other.md is completely unreferenced
        try "=== node: x ===\nX\n".write(to: source.textsDir.appendingPathComponent("other.md"), atomically: true, encoding: .utf8)
        let issues = StoryValidator().validate(story: story, source: source)
        #expect(issues.contains { $0.kind == .orphanTextSection && $0.severity == .warning })
        #expect(issues.contains { $0.kind == .orphanMarkdownFile && $0.severity == .warning })
    }

    @Test("Actor/entity/global validations")
    func actorEntityGlobalValidations() async throws {
        let n = NodeID(rawValue: "N")
        // Node with duplicate actors and unknown entity ref
        let node = Node(
            id: n,
            text: TextRef(file: "t.md", section: "n"),
            choices: [],
            actors: [
                ActorDescriptor(id: "a1", ref: "orc"),
                ActorDescriptor(id: "a1", ref: "goblin") // duplicate id
            ]
        )
        var story = Story(metadata: .init(id: "s", title: "S"), start: n, nodes: [n: node])
        // Only define one of the referenced entities
        story.entities = ["goblin": EntityDescriptor(name: "Goblin")]
        // Global action points to a missing node
        story.globals = Globals(globalActions: [
            "playerDied": GlobalAction(title: "You Died", destination: NodeID(rawValue: "NOPE"))
        ])
        let issues = StoryValidator().validate(story: story)
        #expect(issues.contains { $0.kind == .duplicateActorID && $0.severity == .error })
        #expect(issues.contains { $0.kind == .unknownEntity && $0.severity == .error })
        #expect(issues.contains { $0.kind == .invalidGlobalActionDestination && $0.severity == .error })
    }

    @Test("Fixture decodes actors and entities")
    func fixtureDecodesActorsAndEntities() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let root = cwd.appendingPathComponent("Tests/Fixtures/TinyStory")
        let story = try StoryLoader().loadStory(from: root.appendingPathComponent("story.json"))
        #expect(story.entities.keys.contains("rat"))
        let start = NodeID(rawValue: "start")
        #expect(story.nodes[start]?.actors.contains(where: { $0.id == "r1" && $0.ref == "rat" }) == true)
    }

    @Test("Direct Node decode with actors")
    func directNodeDecodeWithActors() throws {
        let json = """
        {"id":"n","text":{"file":"t.md","section":"s"},"actors":[{"id":"a1","ref":"ent"}],"choices":[]}
        """
        let data = json.data(using: .utf8)!
        let node = try JSONDecoder().decode(Node.self, from: data)
        #expect(node.actors.contains { $0.id == "a1" && $0.ref == "ent" })
    }

    @Test("ActorDescriptor decodes")
    func actorDescriptorDecodes() throws {
        let json = """
        [{"id":"a1","ref":"ent"}]
        """
        let data = json.data(using: .utf8)!
        let arr = try JSONDecoder().decode([ActorDescriptor].self, from: data)
        #expect(arr.count == 1)
        #expect(arr.first?.id == "a1")
        #expect(arr.first?.ref == "ent")
    }

    @Test("Missing choice title is error")
    func missingChoiceTitleIsError() {
        let a = NodeID(rawValue: "A")
        let b = NodeID(rawValue: "B")
        let story = Story(
            metadata: .init(id: "s", title: "S"),
            start: a,
            nodes: [
                a: Node(
                    id: a,
                    text: TextRef(file: "t.md", section: "a"),
                    choices: [
                        Choice(id: ChoiceID(rawValue: "good"), title: "Good Choice", destination: b),
                        Choice(id: ChoiceID(rawValue: "bad"), title: nil, destination: b), // Missing title
                        Choice(id: ChoiceID(rawValue: "empty"), title: "   ", destination: b) // Empty title
                    ]
                ),
                b: Node(id: b, text: TextRef(file: "t.md", section: "b"), choices: [])
            ]
        )
        let issues = StoryValidator().validate(story: story)
        let titleErrors = issues.filter { $0.kind == .missingChoiceTitle && $0.severity == .error }
        #expect(titleErrors.count == 2) // Should find both the nil and empty title
        #expect(titleErrors.contains { $0.message.contains("bad") })
        #expect(titleErrors.contains { $0.message.contains("empty") })
    }

    @Test("Valid choice titles pass validation")
    func validChoiceTitlesPassValidation() {
        let a = NodeID(rawValue: "A")
        let b = NodeID(rawValue: "B")
        let story = Story(
            metadata: .init(id: "s", title: "S"),
            start: a,
            nodes: [
                a: Node(
                    id: a,
                    text: TextRef(file: "t.md", section: "a"),
                    choices: [
                        Choice(id: ChoiceID(rawValue: "choice1"), title: "Go to B", destination: b),
                        Choice(id: ChoiceID(rawValue: "choice2"), title: "Another option", destination: b)
                    ]
                ),
                b: Node(id: b, text: TextRef(file: "t.md", section: "b"), choices: [])
            ]
        )
        let issues = StoryValidator().validate(story: story)
        let titleErrors = issues.filter { $0.kind == .missingChoiceTitle }
        #expect(titleErrors.isEmpty) // Should have no title errors
    }
}
