import Foundation

/// Serializes replacement so an old activity releases its slot before a new one starts.
@MainActor
final class SingleLiveActivityCoordinator {
    struct Entry {
        let id: String
        let key: String
        let isRunning: Bool
    }
    private var tail: Task<Void, Error>?

    func ensure(key: String, current: @escaping () -> [Entry],
                end: @escaping (String) async -> Void,
                start: @escaping () async throws -> Void) async throws {
        try await run {
            let entries = current()
            let keep = entries.first { $0.key == key && $0.isRunning }
            for entry in entries where entry.id != keep?.id { await end(entry.id) }
            if keep == nil { try await start() }
        }
    }

    func run(_ operation: @escaping @MainActor () async throws -> Void) async throws {
        let previous = tail
        let next = Task { @MainActor in
            _ = try? await previous?.value
            try await operation()
        }
        tail = next
        try await next.value
    }
}
