import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

@MainActor
struct LiveActivityLifecycleTests {
    private final class System {
        var entries: [SingleLiveActivityCoordinator.Entry] = []
        var starts = 0
        enum Failure: Error { case quota }
        func end(_ id: String) async {
            await Task.yield()
            entries.removeAll { $0.id == id }
        }
        func start(_ key: String) throws {
            guard entries.count < 2 else { throw Failure.quota }
            starts += 1
            entries.append(.init(id: UUID().uuidString, key: key, isRunning: true))
        }
    }

    @Test func fullQuotaOfLegacyTestsIsReleasedBeforeStartingRealTimer() async throws {
        let system = System()
        system.entries = [.init(id: "test1", key: "test", isRunning: true),
                          .init(id: "test2", key: "test", isRunning: true)]
        let coordinator = SingleLiveActivityCoordinator()
        try await coordinator.ensure(key: "record", current: { system.entries }, end: system.end) {
            try system.start("record")
        }
        #expect(system.entries.count == 1)
        #expect(system.entries.first?.key == "record")
    }

    @Test func overlappingStartsForSameRecordCreateOnlyOneActivity() async throws {
        let system = System()
        let coordinator = SingleLiveActivityCoordinator()
        let first = Task { @MainActor in
            try await coordinator.ensure(key: "record", current: { system.entries }, end: system.end) {
                await Task.yield()
                try system.start("record")
            }
        }
        let second = Task { @MainActor in
            try await coordinator.ensure(key: "record", current: { system.entries }, end: system.end) {
                try system.start("record")
            }
        }
        try await first.value
        try await second.value
        #expect(system.entries.count == 1)
        #expect(system.starts == 1)
    }

    @Test func existingTimerIsReusedWhileDuplicateAndEndedItemsAreRemoved() async throws {
        let system = System()
        system.entries = [.init(id: "current", key: "record", isRunning: true),
                          .init(id: "duplicate", key: "record", isRunning: true),
                          .init(id: "ended", key: "old", isRunning: false)]
        let coordinator = SingleLiveActivityCoordinator()
        try await coordinator.ensure(key: "record", current: { system.entries }, end: system.end) {
            try system.start("record")
        }
        #expect(system.entries.map(\.id) == ["current"])
        #expect(system.starts == 0)
    }

    @Test func failedRequestDoesNotBlockLaterRetry() async throws {
        let coordinator = SingleLiveActivityCoordinator()
        await #expect(throws: System.Failure.self) {
            try await coordinator.run { throw System.Failure.quota }
        }
        var retried = false
        try await coordinator.run { retried = true }
        #expect(retried)
    }
}
