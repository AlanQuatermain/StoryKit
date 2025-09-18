import Foundation
import ArgumentParser
import StoryKit

@main
struct Haunted: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Play a StoryKit bundle")

    @Option(name: .shortAndLong, help: "Path to compiled .storybundle directory")
    var bundle: String

    func run() throws {
        let story = try loadStory(from: bundle)
        try play(story: story, bundlePath: bundle)
    }
}

