import Foundation
import Testing
@testable import Persistence
import Core

private struct S: StoryState { var currentNode: NodeID }

@Suite("Persistence")
struct PersistenceTests {
    @Test
    func inMemorySaveAndLoad() async throws {
        let provider = InMemorySaveProvider<S>()
        let s = S(currentNode: NodeID(rawValue: "x"))
        let save = StorySave<S>(storyID: "id", state: s)
        try await provider.save(slot: "slot1", snapshot: save)
        let loaded = try await provider.load(slot: "slot1")
        #expect(loaded?.storyID == "id")
        #expect(loaded?.state.currentNode.rawValue == "x")
        let slots = await provider.listSlots()
        #expect(slots.contains("slot1"))
    }

    @Test
    func jsonFileSaveAndLoad() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let provider = JSONFileSaveProvider<S>(directory: dir)
        let s = S(currentNode: NodeID(rawValue: "y"))
        let save = StorySave<S>(storyID: "id2", state: s)
        try await provider.save(slot: "slotA", snapshot: save)
        let loaded = try await provider.load(slot: "slotA")
        #expect(loaded?.storyID == "id2")
        #expect(loaded?.state.currentNode.rawValue == "y")
        let slots = await provider.listSlots()
        #expect(slots.contains("slotA"))
    }

    @Test
    func listSlotsIsSortedAndOverwriteWorks() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let provider = JSONFileSaveProvider<S>(directory: dir)
        // Save two slots out of order
        try await provider.save(slot: "slotB", snapshot: StorySave<S>(storyID: "idB", state: S(currentNode: NodeID(rawValue: "b"))))
        try await provider.save(slot: "slotA", snapshot: StorySave<S>(storyID: "idA", state: S(currentNode: NodeID(rawValue: "a"))))
        let slots = await provider.listSlots()
        #expect(slots == ["slotA", "slotB"]) // sorted

        // Overwrite slotA
        try await provider.save(slot: "slotA", snapshot: StorySave<S>(storyID: "idA2", state: S(currentNode: NodeID(rawValue: "a2"))))
        let loaded = try await provider.load(slot: "slotA")
        #expect(loaded?.storyID == "idA2")
        #expect(loaded?.state.currentNode.rawValue == "a2")
    }
}
