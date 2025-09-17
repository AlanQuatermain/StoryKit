import Foundation
import Core
import ContentIO

// Simple CLI: sync tutorial code listings with story files inside zipped resources or a directory.
// Usage examples:
//   # From a ZIP bundled with the docs
//   swift run SyncSnippets --direction source-to-snippets --zip haunted-after --changed story.json --changed texts/haunted.md
//   swift run SyncSnippets --direction snippets-to-source --zip haunted-after --changed Sources/StoryKit/StoryKit.docc/Tutorials/01-building-code-03.json
//
//   # From a directory on disk (authoring root containing story.json and texts/)
//   swift run SyncSnippets --direction source-to-snippets --dir /absolute/path/to/haunted-after
//   swift run SyncSnippets --direction snippets-to-source --dir /absolute/path/to/haunted-after --changed Sources/StoryKit/StoryKit.docc/Tutorials/01-building-code-04.txt

enum Direction: String { case sourceToSnippets = "source-to-snippets", snippetsToSource = "snippets-to-source" }

struct CLI {
    var direction: Direction
    var zipName: String? // haunted-before | haunted-after
    var dirPath: String? // path to a directory with story.json and texts/
    var changed: [String]
}

func parseCLI() -> CLI? {
    var dir: Direction?
    var zip: String?
    var dirPathOpt: String?
    var changed: [String] = []
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let a = it.next() {
        switch a {
        case "--direction":
            if let v = it.next(), let d = Direction(rawValue: v) { dir = d }
        case "--zip":
            if let v = it.next() { zip = v }
        case "--dir":
            if let v = it.next() { dirPathOpt = v }
        case "--changed":
            if let v = it.next() { changed.append(v) }
        case "--help", "-h":
            print("SyncSnippets usage:\n  --direction source-to-snippets|snippets-to-source\n  --zip haunted-before|haunted-after  (or)  --dir <authoring-root>\n  --changed <path> (repeat)\n")
            return nil
        default:
            continue
        }
    }
    guard let d = dir else {
        print("error: missing --direction")
        return nil
    }
    if zip == nil && dirPathOpt == nil {
        print("error: provide either --zip or --dir")
        return nil
    }
    if changed.isEmpty { changed = ["story.json", "texts/haunted.md"] }
    return CLI(direction: d, zipName: zip, dirPath: dirPathOpt, changed: changed)
}

func doccRoot() -> URL {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return cwd.appendingPathComponent("Sources/StoryKit/StoryKit.docc")
}

func zipURL(_ name: String) -> URL { doccRoot().appendingPathComponent("Resources/zips/\(name).zip") }
func tutorialsDir() -> URL { doccRoot().appendingPathComponent("Tutorials") }

func run(_ tool: String, _ args: [String]) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    try p.run()
    p.waitUntilExit()
    if p.terminationStatus != 0 { throw NSError(domain: "SyncSnippets", code: Int(p.terminationStatus)) }
}

func unzip(_ zip: URL, to dst: URL) throws {
    try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
    try run("/usr/bin/unzip", [zip.path, "-d", dst.path])
}

func rezip(from dir: URL, to zip: URL) throws {
    // Remove existing zip then write new one
    let fm = FileManager.default
    if fm.fileExists(atPath: zip.path) { try? fm.removeItem(at: zip) }
    let cwd = fm.currentDirectoryPath
    fm.changeCurrentDirectoryPath(dir.path)
    defer { fm.changeCurrentDirectoryPath(cwd) }
    try run("/usr/bin/zip", ["-qr", zip.path, "."])
}

func loadJSON(_ url: URL) throws -> Any {
    let data = try Data(contentsOf: url)
    return try JSONSerialization.jsonObject(with: data)
}

func saveJSON(_ obj: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

func extractSections(_ text: String) -> [String: String] {
    var sections: [String: String] = [:]
    var current: String? = nil
    var buffer: [String] = []
    func flush() {
        if let id = current { sections[id] = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
        buffer.removeAll(keepingCapacity: true)
    }
    for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
        if let range = line.range(of: #"^===\s*node:\s*(.*?)\s*===\s*$"#, options: .regularExpression) {
            flush()
            let header = String(line[range])
            let id = header.replacingOccurrences(of: "===", with: "").replacingOccurrences(of: "node:", with: "").replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespaces)
            current = id
        } else {
            buffer.append(line)
        }
    }
    flush()
    return sections
}

func buildText(from sections: [(String, String)]) -> String {
    var out: [String] = []
    for (id, body) in sections {
        out.append("=== node: \(id) ===")
        out.append(body)
        out.append("")
    }
    return out.joined(separator: "\n")
}

func updateSnippetsFromSource(zipRoot: URL, changed: [String]) throws {
    let tutDir = tutorialsDir()
    let storyURL = zipRoot.appendingPathComponent("story.json")
    if changed.contains("story.json"),
       let snippetURLs = try? FileManager.default.contentsOfDirectory(at: tutDir, includingPropertiesForKeys: nil).filter({ $0.pathExtension == "json" }) {
        let storyObj = try loadJSON(storyURL) as! [String: Any]
        let nodes = storyObj["nodes"] as? [String: Any] ?? [:]
        let start = storyObj["start"]
        for snip in snippetURLs {
            guard var snipObj = try? loadJSON(snip) as? [String: Any] else { continue }
            if snipObj.keys.contains("nodes") {
                var newNodes: [String: Any] = [:]
                if let snipNodes = snipObj["nodes"] as? [String: Any] {
                    for (k, _) in snipNodes { if let n = nodes[k] { newNodes[k] = n } }
                }
                snipObj["nodes"] = newNodes
                if start != nil { snipObj["start"] = start }
                try saveJSON(snipObj, to: snip)
            } else if let id = snipObj["id"] as? String, let node = nodes[id] {
                if let nodeDict = node as? [String: Any] { try saveJSON(nodeDict, to: snip) }
            }
        }
    }
    if changed.contains("texts/haunted.md") {
        let srcTextURL = zipRoot.appendingPathComponent("texts/haunted.md")
        if let srcText = try? String(contentsOf: srcTextURL, encoding: .utf8) {
            let srcSections = extractSections(srcText)
            // Update any .txt snippet with section headers present
            if let snippetURLs = try? FileManager.default.contentsOfDirectory(at: tutDir, includingPropertiesForKeys: nil).filter({ $0.pathExtension == "txt" }) {
                for snip in snippetURLs {
                    let snipText = (try? String(contentsOf: snip, encoding: .utf8)) ?? ""
                    let snipSecs = extractSections(snipText)
                    if snipSecs.isEmpty { continue }
                    var out: [(String, String)] = []
                    for id in snipSecs.keys { if let body = srcSections[id] { out.append((id, body)) } }
                    if !out.isEmpty { try buildText(from: out).write(to: snip, atomically: true, encoding: .utf8) }
                }
            }
        }
    }
}

func updateSourceFromSnippets(zipRoot: URL, changedSnippetPaths: [String]) throws {
    let fm = FileManager.default
    let resolved = changedSnippetPaths.map { URL(fileURLWithPath: $0, relativeTo: URL(fileURLWithPath: fm.currentDirectoryPath)).standardized }
    // Collect matching snippet files
    let storyURL = zipRoot.appendingPathComponent("story.json")
    var storyObj = try loadJSON(storyURL) as! [String: Any]
    var nodes = storyObj["nodes"] as? [String: Any] ?? [:]
    for snip in resolved {
        if snip.pathExtension == "json" {
            if let snipObj = try? loadJSON(snip) as? [String: Any] {
                if snipObj.keys.contains("nodes") {
                    if let snipNodes = snipObj["nodes"] as? [String: Any] {
                        for (k, v) in snipNodes { nodes[k] = v }
                    }
                    if let s = snipObj["start"] { storyObj["start"] = s }
                } else if let id = snipObj["id"] as? String {
                    nodes[id] = snipObj
                }
            }
        } else if snip.pathExtension == "txt" {
            // Update texts/haunted.md sections
            let textURL = zipRoot.appendingPathComponent("texts/haunted.md")
            var dstText = (try? String(contentsOf: textURL, encoding: .utf8)) ?? ""
            let dstSections = extractSections(dstText)
            let snipText = (try? String(contentsOf: snip, encoding: .utf8)) ?? ""
            let snipSections = extractSections(snipText)
            var combined = dstSections
            for (id, body) in snipSections { combined[id] = body }
            // Write combined preserving order: use snippet order first then others
            var ordered: [(String, String)] = []
            for (id, body) in snipSections { ordered.append((id, body)) }
            for (id, body) in dstSections where snipSections[id] == nil { ordered.append((id, body)) }
            let out = buildText(from: ordered)
            try out.write(to: textURL, atomically: true, encoding: .utf8)
        }
    }
    storyObj["nodes"] = nodes
    try saveJSON(storyObj, to: storyURL)
    // Keep graph.json mirrored
    try saveJSON(storyObj, to: zipRoot.appendingPathComponent("graph.json"))
}

// Main
guard let cli = parseCLI() else { exit(2) }

do {
    if let name = cli.zipName {
        // Work inside a temp dir for zip-based flows
        let z = zipURL(name)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try unzip(z, to: tmp)
        switch cli.direction {
        case .sourceToSnippets:
            try updateSnippetsFromSource(zipRoot: tmp, changed: cli.changed)
        case .snippetsToSource:
            try updateSourceFromSnippets(zipRoot: tmp, changedSnippetPaths: cli.changed)
            try rezip(from: tmp, to: z)
            print("Updated zip: \(z.path)")
        }
    } else if let dirPath = cli.dirPath {
        // Work directly in the given directory
        let root = URL(fileURLWithPath: dirPath)
        switch cli.direction {
        case .sourceToSnippets:
            try updateSnippetsFromSource(zipRoot: root, changed: cli.changed)
        case .snippetsToSource:
            try updateSourceFromSnippets(zipRoot: root, changedSnippetPaths: cli.changed)
            print("Updated directory: \(root.path)")
        }
    }
} catch {
    fputs("SyncSnippets error: \(error)\n", stderr)
    exit(1)
}
