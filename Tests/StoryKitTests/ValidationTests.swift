import Foundation
import Testing
@testable import ContentIO
import Core

@Test
func validator_severity_checks() async throws {
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
