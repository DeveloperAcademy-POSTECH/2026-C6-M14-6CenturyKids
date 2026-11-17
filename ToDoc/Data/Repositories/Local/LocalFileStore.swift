import Foundation

/// 기록 하나를 JSON 파일 하나로 통째로 바꿔 씁니다. 읽기 오류는 빈 목록으로 넘기지 않고 그대로 알립니다.
final class LocalFileStore {
    static let defaultDirectory = URL.applicationSupportDirectory.appending(path: "OfflineBooth", directoryHint: .isDirectory)
    private let directory: URL
    private static let lock = NSRecursiveLock()

    init(directory: URL = defaultDirectory) { self.directory = directory }

    func read<T: Decodable>(_ type: T.Type, collection: String, id: UUID) throws -> T? {
        try locked {
            let url = path(collection, id)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        }
    }

    func all<T: Decodable>(_ type: T.Type, collection: String) throws -> [T] {
        try locked {
            let folder = directory.appending(path: collection)
            guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
            return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .map { try JSONDecoder().decode(T.self, from: Data(contentsOf: $0)) }
        }
    }

    func write<T: Encodable>(_ value: T, collection: String, id: UUID) throws {
        try locked {
            let url = path(collection, id)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var root = directory
            try root.setResourceValues(values)
            let data = try JSONEncoder().encode(value)
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: url, options: .atomic)
            #endif
        }
    }

    func delete(collection: String, id: UUID) throws {
        try locked {
            let url = path(collection, id)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    func locked<T>(_ work: () throws -> T) rethrows -> T {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return try work()
    }

    private func path(_ collection: String, _ id: UUID) -> URL {
        directory.appending(path: collection).appending(path: "\(id.uuidString).json")
    }
}
