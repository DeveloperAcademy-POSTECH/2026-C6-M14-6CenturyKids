//
//  FileNotificationRepository.swift
//  ToDoc
//
//  Created by seokho on 10/27/26.
//

import Foundation

#if canImport(ToDocDomain)
import ToDocDomain // 테스트 패키지에서는 Domain이 별도 모듈
#endif

/// 앱 알림 목록을 서버 없이 폰에만 남긴다 (환자마다 JSON 하나). 30일이 지난 알림은 지운다.
/// 병원 도착은 폰이 잠긴 채 백그라운드에서 저장되므로, 잠금을 한 번 푼 뒤로는 잠겨 있어도 쓸 수 있게 저장한다
final class FileNotificationRepository: NotificationRepository {
    static let retention: TimeInterval = 30 * 24 * 60 * 60

    private let directory: URL
    private let now: () -> Date

    init(directory: URL = .applicationSupportDirectory.appending(path: "Notifications", directoryHint: .isDirectory),
         now: @escaping () -> Date = Date.init) {
        self.directory = directory
        self.now = now
    }

    func save(notification: AppNotification, for patientId: UUID) async throws {
        var stored = try load(patientId).filter { $0.id != notification.id }
        stored.append(Stored(notification))
        try write(stored, for: patientId)
    }

    func findById(_ id: UUID) async throws -> AppNotification? {
        try allFiles().lazy.flatMap { (try? self.decode($0)) ?? [] }.first { $0.id == id }?.domain ?? nil
    }

    /// 최근 알림부터
    func findByUserId(_ userId: UUID) async throws -> [AppNotification] {
        try load(userId).compactMap(\.domain).sorted { $0.createdAt > $1.createdAt }
    }

    func countUnreadByUserId(_ userId: UUID) async throws -> Int {
        try load(userId).filter { $0.readAt == nil }.count
    }

    func markAsRead(_ id: UUID) async throws {
        for url in try allFiles() {
            var stored = try decode(url)
            guard let index = stored.firstIndex(where: { $0.id == id }) else { continue }
            guard stored[index].readAt == nil else { return }
            stored[index].readAt = now()
            try write(stored, to: url)
            return
        }
    }

    /// 보관 기간이 지난 알림은 읽을 때 뺀다 (다음 저장 때 파일에서도 빠진다)
    private func load(_ patientId: UUID) throws -> [Stored] {
        let url = url(for: patientId)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        let oldest = now().addingTimeInterval(-Self.retention)
        return try decode(url).filter { $0.createdAt >= oldest }
    }

    private func decode(_ url: URL) throws -> [Stored] {
        try JSONDecoder().decode([Stored].self, from: Data(contentsOf: url))
    }

    private func write(_ stored: [Stored], for patientId: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var noBackup = URLResourceValues()
        noBackup.isExcludedFromBackup = true
        var root = directory
        try root.setResourceValues(noBackup)
        try write(stored, to: url(for: patientId))
    }

    private func write(_ stored: [Stored], to url: URL) throws {
        try JSONEncoder().encode(stored).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func allFiles() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }

    private func url(for patientId: UUID) -> URL {
        directory.appending(path: "\(patientId.uuidString).json")
    }

    private struct Stored: Codable {
        let id: UUID
        let type: String
        let title: String
        let body: String
        let targetId: UUID
        let createdAt: Date
        var readAt: Date?

        init(_ notification: AppNotification) {
            id = notification.id
            type = notification.type.rawValue
            title = notification.title
            body = notification.body
            targetId = notification.targetId
            createdAt = notification.createdAt
            readAt = notification.readAt
        }

        /// 이 버전이 모르는 종류는 건너뛴다
        var domain: AppNotification? {
            guard let type = NotificationType(rawValue: type) else { return nil }
            return AppNotification(id: id, type: type, title: title, body: body,
                                   targetId: targetId, createdAt: createdAt, readAt: readAt)
        }
    }
}
