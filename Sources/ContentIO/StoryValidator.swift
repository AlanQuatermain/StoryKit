import Foundation
import Core

public struct StoryIssue: Hashable, CustomStringConvertible, Sendable {
    public enum Kind: String, Sendable {
        case missingStart
        case missingDestination
        case unreachableNode
        case duplicateChoiceID
        case textSectionMissing
        case orphanTextSection
        case nodeKeyMismatch
    }
    public var kind: Kind
    public var message: String
    public init(_ kind: Kind, _ message: String) {
        self.kind = kind
        self.message = message
    }
    public var description: String { message }
}

public struct StoryValidator: Sendable {
    public init() {}

    // Structural validation on the Story graph only.
    public func validate(story: Story) -> [StoryIssue] {
        var issues: [StoryIssue] = []

        // start node exists
        if story.nodes[story.start] == nil {
            issues.append(.init(.missingStart, "Missing start node: \(story.start.rawValue)"))
        }

        // node key and id consistency; destination existence; duplicate choice IDs per node
        for (key, node) in story.nodes {
            if key != node.id { issues.append(.init(.nodeKeyMismatch, "Node key \(key.rawValue) != node.id \(node.id.rawValue)")) }
            var seen: Set<ChoiceID> = []
            for c in node.choices {
                if !seen.insert(c.id).inserted {
                    issues.append(.init(.duplicateChoiceID, "Duplicate choice id \(c.id.rawValue) in node \(node.id.rawValue)"))
                }
                if story.nodes[c.destination] == nil {
                    issues.append(.init(.missingDestination, "Node \(node.id.rawValue) has choice \(c.id.rawValue) to missing node \(c.destination.rawValue)"))
                }
            }
        }

        // reachability from start
        if let _ = story.nodes[story.start] {
            var visited: Set<NodeID> = []
            var queue: [NodeID] = [story.start]
            while let id = queue.first {
                queue.removeFirst()
                if visited.contains(id) { continue }
                visited.insert(id)
                if let node = story.nodes[id] {
                    for c in node.choices { queue.append(c.destination) }
                }
            }
            for id in story.nodes.keys where !visited.contains(id) {
                issues.append(.init(.unreachableNode, "Unreachable node: \(id.rawValue)"))
            }
        }

        return issues
    }

    // Extended validation that checks Markdown text sections against source layout.
    public func validate(story: Story, source: StorySourceLayout) -> [StoryIssue] {
        var issues = validate(story: story)

        let fm = FileManager.default
        let textsDir = source.textsDir
        guard fm.fileExists(atPath: textsDir.path) else { return issues }

        // Gather referenced text sections
        var referenced: [String: Set<String>] = [:] // file -> sections
        for node in story.nodes.values {
            referenced[node.text.file, default: []].insert(node.text.section)
        }

        // Parse all markdown files in texts dir
        let parser = TextSectionParser()
        var available: [String: Set<String>] = [:]
        if let items = try? fm.contentsOfDirectory(at: textsDir, includingPropertiesForKeys: nil) {
            for item in items where item.pathExtension.lowercased() == "md" {
                if let content = try? String(contentsOf: item, encoding: .utf8) {
                    let sections = Set(parser.parseSections(markdown: content).keys)
                    available[item.lastPathComponent] = sections
                }
            }
        }

        // Check for missing sections
        for (file, sections) in referenced {
            let avail = available[file] ?? []
            for s in sections where !avail.contains(s) {
                issues.append(.init(.textSectionMissing, "Missing text section '\(s)' in file \(file)"))
            }
        }

        // Orphan sections = present but not referenced by any node
        let referencedPairs = Set(referenced.flatMap { (file, set) in set.map { (file, $0) } }.map { "\($0)@\($1)" })
        for (file, sections) in available {
            for s in sections {
                let key = "\(file)@\(s)"
                if !referencedPairs.contains(key) {
                    issues.append(.init(.orphanTextSection, "Orphan text section '\(s)' in file \(file)"))
                }
            }
        }

        return issues
    }
}

