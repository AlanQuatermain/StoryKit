import Foundation
import Core

public struct StoryIssue: Codable, Hashable, CustomStringConvertible, Sendable {
    public enum Kind: String, Codable, Sendable {
        case missingStart
        case missingDestination
        case unreachableNode
        case duplicateChoiceID
        case textSectionMissing
        case orphanTextSection
        case nodeKeyMismatch
        case orphanMarkdownFile
        case emptyChoices
        case noExitCycle
    }
    public enum Severity: String, Sendable, Codable { case error, warning }
    public var kind: Kind
    public var severity: Severity
    public var message: String
    public init(_ kind: Kind, _ message: String, severity: Severity) {
        self.kind = kind
        self.message = message
        self.severity = severity
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
            issues.append(.init(.missingStart, "Missing start node: \(story.start.rawValue)", severity: .error))
        }

        // node key and id consistency; destination existence; duplicate choice IDs per node
        for (key, node) in story.nodes {
            if key != node.id { issues.append(.init(.nodeKeyMismatch, "Node key \(key.rawValue) != node.id \(node.id.rawValue)", severity: .warning)) }
            var seen: Set<ChoiceID> = []
            for c in node.choices {
                if !seen.insert(c.id).inserted {
                    issues.append(.init(.duplicateChoiceID, "Duplicate choice id \(c.id.rawValue) in node \(node.id.rawValue)", severity: .error))
                }
                if story.nodes[c.destination] == nil {
                    issues.append(.init(.missingDestination, "Node \(node.id.rawValue) has choice \(c.id.rawValue) to missing node \(c.destination.rawValue)", severity: .error))
                }
            }
        }

        // reachability from start and empty-choices checks
        if let _ = story.nodes[story.start] {
            var visited: Set<NodeID> = []
            var queue: [NodeID] = [story.start]
            while let id = queue.first {
                queue.removeFirst()
                if visited.contains(id) { continue }
                visited.insert(id)
                if let node = story.nodes[id] {
                    if node.choices.isEmpty { issues.append(.init(.emptyChoices, "Node has no choices: \(id.rawValue)", severity: .warning)) }
                    for c in node.choices { queue.append(c.destination) }
                }
            }
            for id in story.nodes.keys where !visited.contains(id) {
                issues.append(.init(.unreachableNode, "Unreachable node: \(id.rawValue)", severity: .error))
            }

            // detect cycles with no exits among reachable nodes
            let reachableNodes = visited
            let adj: [NodeID: [NodeID]] = Dictionary(uniqueKeysWithValues: reachableNodes.map { id in
                let outs = story.nodes[id]?.choices.map { $0.destination } ?? []
                return (id, outs)
            })
            for scc in stronglyConnectedComponents(adj: adj) {
                // edges leaving the SCC
                let set = Set(scc)
                let outgoing = scc.flatMap { id in (adj[id] ?? []).filter { !set.contains($0) } }
                let hasNoExit = outgoing.isEmpty
                let hasCycle = scc.count > 1 || (scc.count == 1 && (adj[scc[0]] ?? []).contains(scc[0]))
                if hasNoExit && hasCycle {
                    let list = scc.map { $0.rawValue }.sorted().joined(separator: ", ")
                    issues.append(.init(.noExitCycle, "Cycle with no exits involving: [\(list)]", severity: .warning))
                }
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
                issues.append(.init(.textSectionMissing, "Missing text section '\(s)' in file \(file)", severity: .error))
            }
        }

        // Orphan sections = present but not referenced by any node
        let referencedPairs = Set(referenced.flatMap { (file, set) in set.map { (file, $0) } }.map { "\($0)@\($1)" })
        for (file, sections) in available {
            for s in sections {
                let key = "\(file)@\(s)"
                if !referencedPairs.contains(key) {
                    issues.append(.init(.orphanTextSection, "Orphan text section '\(s)' in file \(file)", severity: .warning))
                }
            }
            if sections.isEmpty, !(referenced[file]?.isEmpty ?? true) == false {
                // file has no sections parsed at all
                issues.append(.init(.orphanMarkdownFile, "Markdown file has no parseable sections: \(file)", severity: .warning))
            }
            if (referenced[file]?.isEmpty ?? true) {
                // no references to this file at all
                issues.append(.init(.orphanMarkdownFile, "Orphan Markdown file (no nodes reference it): \(file)", severity: .warning))
            }
        }

        return issues
    }

    // Validate against a compiled .storybundle
    public func validate(story: Story, bundle: StoryBundleLayout) -> [StoryIssue] {
        var issues = validate(story: story)
        let fm = FileManager.default
        let textsDir = bundle.textsDir
        guard fm.fileExists(atPath: textsDir.path) else { return issues }

        var referenced: [String: Set<String>] = [:]
        for node in story.nodes.values { referenced[node.text.file, default: []].insert(node.text.section) }

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

        for (file, sections) in referenced {
            let avail = available[file] ?? []
            for s in sections where !avail.contains(s) {
                issues.append(.init(.textSectionMissing, "Missing text section '\(s)' in bundle file \(file)", severity: .error))
            }
        }

        let referencedPairs = Set(referenced.flatMap { (file, set) in set.map { (file, $0) } }.map { "\($0)@\($1)" })
        for (file, sections) in available {
            for s in sections {
                let key = "\(file)@\(s)"
                if !referencedPairs.contains(key) {
                    issues.append(.init(.orphanTextSection, "Orphan text section '\(s)' in bundle file \(file)", severity: .warning))
                }
            }
            if sections.isEmpty, (referenced[file]?.isEmpty ?? true) {
                issues.append(.init(.orphanMarkdownFile, "Markdown file has no parseable sections: \(file)", severity: .warning))
            }
            if (referenced[file]?.isEmpty ?? true) {
                issues.append(.init(.orphanMarkdownFile, "Orphan Markdown file (no nodes reference it): \(file)", severity: .warning))
            }
        }

        return issues
    }
}

// MARK: - Strongly Connected Components (Tarjan)

fileprivate func stronglyConnectedComponents(adj: [NodeID: [NodeID]]) -> [[NodeID]] {
    var index: Int = 0
    var indices: [NodeID: Int] = [:]
    var lowlink: [NodeID: Int] = [:]
    var stack: [NodeID] = []
    var onStack: Set<NodeID> = []
    var result: [[NodeID]] = []

    func strongConnect(_ v: NodeID) {
        indices[v] = index
        lowlink[v] = index
        index += 1
        stack.append(v)
        onStack.insert(v)

        for w in adj[v] ?? [] {
            if indices[w] == nil {
                strongConnect(w)
                lowlink[v] = min(lowlink[v]!, lowlink[w]!)
            } else if onStack.contains(w) {
                lowlink[v] = min(lowlink[v]!, indices[w]!)
            }
        }

        if lowlink[v] == indices[v] {
            var scc: [NodeID] = []
            while let w = stack.popLast() {
                onStack.remove(w)
                scc.append(w)
                if w == v { break }
            }
            result.append(scc)
        }
    }

    for v in adj.keys where indices[v] == nil { strongConnect(v) }
    return result
}
