import Foundation
import CryptoKit
import Core

/// Metadata describing a compiled story bundle.
public struct StoryBundleManifest: Codable, Sendable {
    /// A monotonically increasing schema version for bundle consumers.
    public var schemaVersion: Int
    /// The story identifier from metadata.
    public var storyID: String
    /// The story title from metadata.
    public var title: String
    /// The story semantic version from metadata.
    public var version: Int
    /// A SHA-256 hash of `graph.json` (hex encoded) to detect changes.
    public var graphHashSHA256: String
    /// The build timestamp of this bundle.
    public var builtAt: Date
}

/// Computes a hex-encoded SHA-256 digest.
func sha256Hex(of data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}
