import Foundation
import ArgumentParser
import StoryKit

@main
struct Haunted: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Play a StoryKit bundle")

    @Argument(help: "Path to compiled .storybundle directory")
    var bundlePath: String
}

