import Foundation
import CryptoKit
import Core

public struct StoryBundleManifest: Codable, Sendable {
    public var schemaVersion: Int
    public var storyID: String
    public var title: String
    public var version: Int
    public var graphHashSHA256: String
    public var builtAt: Date
}

func sha256Hex(of data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

