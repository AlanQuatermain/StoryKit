import Foundation
import ArgumentParser
import ContentIO
import Core

@main
struct StoryKitCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "storykit",
        abstract: "Story authoring utilities (validate, graph, compile)",
        version: "0.1.0",
        subcommands: [Validate.self, Graph.self, Compile.self]
    )
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Validate a story source folder")

    @Argument(help: "Path to story source root containing story.json and texts/")
    var path: String

    func run() throws {
        let source = StorySourceLayout(root: URL(fileURLWithPath: path))
        let story = try StoryLoader().loadStory(from: source.storyJSON)
        let issues = StoryValidator().validate(story: story)
        if issues.isEmpty {
            print("✅ No issues found")
        } else {
            for issue in issues { print("- \(issue)") }
            throw ExitCode(1)
        }
    }
}

struct Graph: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export graph in a simple format")

    @Argument(help: "Path to story.json or source folder")
    var path: String

    func run() throws {
        let url = URL(fileURLWithPath: path)
        let jsonURL: URL
        if url.hasDirectoryPath {
            jsonURL = url.appendingPathComponent("story.json")
        } else {
            jsonURL = url
        }
        let story = try StoryLoader().loadStory(from: jsonURL)
        let edges = story.nodes.values.flatMap { node in node.choices.map { (from: node.id.rawValue, to: $0.destination.rawValue) } }
        for e in edges { print("\(e.from) -> \(e.to)") }
    }
}

struct Compile: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Compile a story source into a .storybundle directory")

    @Argument(help: "Path to story source root")
    var input: String

    @Option(name: .shortAndLong, help: "Output .storybundle directory path")
    var out: String

    func run() throws {
        let compiler = StoryCompiler()
        let source = StorySourceLayout(root: URL(fileURLWithPath: input))
        let bundle = StoryBundleLayout(root: URL(fileURLWithPath: out))
        try compiler.compile(source: source, to: bundle)
        print("✅ Wrote bundle to \(bundle.root.path)")
    }
}

// Minimal validator placeholder
struct StoryValidator {
    func validate(story: Story) -> [String] {
        var issues: [String] = []
        // start node exists
        if story.nodes[story.start] == nil {
            issues.append("Missing start node: \(story.start.rawValue)")
        }
        // all choice destinations exist
        for (id, node) in story.nodes {
            for c in node.choices {
                if story.nodes[c.destination] == nil {
                    issues.append("Node \(id.rawValue) has choice \(c.id.rawValue) to missing node \(c.destination.rawValue)")
                }
            }
        }
        return issues
    }
}

