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

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Validate a story source folder")

    @Argument(help: "Path to story source root containing story.json and texts/")
    var path: String

    @Option(help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let url = URL(fileURLWithPath: path)
        if url.hasDirectoryPath {
            // If directory looks like a compiled bundle, use bundle validation. Otherwise treat as source.
            let fm = FileManager.default
            let bundleLayout = StoryBundleLayout(root: url)
            let isBundle = fm.fileExists(atPath: bundleLayout.manifest.path) && fm.fileExists(atPath: bundleLayout.graph.path)
            if isBundle {
                let story = try StoryBundleLoader().load(from: bundleLayout)
                let issues = StoryValidator().validate(story: story, bundle: bundleLayout)
                try output(issues)
                return
            }

            let source = StorySourceLayout(root: url)
            let story = try StoryLoader().loadStory(from: source.storyJSON)
            let issues = StoryValidator().validate(story: story, source: source)
            try output(issues)
        } else {
            let story = try StoryLoader().loadStory(from: url)
            let issues = StoryValidator().validate(story: story)
            try output(issues)
        }
    }

    private func output(_ issues: [StoryIssue]) throws {
        switch format {
        case .text:
            if issues.isEmpty {
                print("✅ No issues found")
            } else {
                for i in issues { print("- [\(i.severity.rawValue.uppercased())] \(i)") }
                if issues.contains(where: { $0.severity == .error }) { throw ExitCode(1) }
            }
        case .json:
            struct Report: Codable { let ok: Bool; let errors: Int; let warnings: Int; let issues: [StoryIssue] }
            let errors = issues.filter { $0.severity == .error }.count
            let warnings = issues.filter { $0.severity == .warning }.count
            let report = Report(ok: issues.isEmpty || errors == 0, errors: errors, warnings: warnings, issues: issues)
            let data = try JSONEncoder().encode(report)
            if let s = String(data: data, encoding: .utf8) { print(s) }
            if errors > 0 { throw ExitCode(1) }
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

// Validation is provided by ContentIO.StoryValidator
