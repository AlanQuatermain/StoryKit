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
    static let configuration = CommandConfiguration(abstract: "Export graph to stdout or a file")

    enum GraphFormat: String, ExpressibleByArgument { case text, dot, json }

    @Argument(help: "Path to story.json or source/bundle directory")
    var path: String

    @Option(name: .shortAndLong, help: "Output format: text, dot, or json")
    var format: GraphFormat = .text

    @Option(name: .shortAndLong, help: "Output file path; omit to write to stdout")
    var out: String?

    func run() throws {
        let story = try loadStory(at: URL(fileURLWithPath: path))
        let output: String
        switch format {
        case .text:
            let edges = story.nodes.values.flatMap { node in node.choices.map { (from: node.id.rawValue, to: $0.destination.rawValue) } }
            output = edges.map { "\($0.from) -> \($0.to)" }.joined(separator: "\n") + "\n"
        case .json:
            struct Edge: Codable { let from: String; let to: String }
            let edges = story.nodes.values.flatMap { node in node.choices.map { Edge(from: node.id.rawValue, to: $0.destination.rawValue) } }
            let data = try JSONEncoder().encode(edges)
            output = String(data: data, encoding: .utf8) ?? "[]"
        case .dot:
            let lines = dotLines(for: story)
            output = lines.joined(separator: "\n") + "\n"
        }

        if let out {
            try output.write(to: URL(fileURLWithPath: out), atomically: true, encoding: .utf8)
        } else {
            print(output, terminator: "")
        }
    }

    private func loadStory(at url: URL) throws -> Story {
        if url.hasDirectoryPath {
            let bundle = StoryBundleLayout(root: url)
            let fm = FileManager.default
            if fm.fileExists(atPath: bundle.graph.path) { // compiled bundle
                return try StoryBundleLoader().load(from: bundle)
            }
            return try StoryLoader().loadStory(from: url.appendingPathComponent("story.json"))
        } else {
            return try StoryLoader().loadStory(from: url)
        }
    }

    private func dotLines(for story: Story) -> [String] {
        var lines: [String] = []
        lines.append("digraph Story {")
        // Optional: declare nodes to ensure isolated nodes appear
        for id in story.nodes.keys {
            lines.append("  \(quote(id.rawValue));")
        }
        for node in story.nodes.values {
            for choice in node.choices {
                lines.append("  \(quote(node.id.rawValue)) -> \(quote(choice.destination.rawValue));")
            }
        }
        lines.append("}")
        return lines
    }

    private func quote(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\"" }
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
