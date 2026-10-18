//
//  FilePendingCareCallRepository.swift
//  ToDoc
//
//  Created by seokho on 10/18/26.
//

import Foundation

/// 아직 올리지 못한 케어콜 기록을 앱 안 파일로 남긴다 (환자 폴더 안에 케어콜마다 JSON 하나).
/// 건강 정보라 폰이 잠겨 있으면 읽을 수 없게 저장하고, iCloud·기기 백업에는 넣지 않는다
final class FilePendingCareCallRepository: PendingCareCallRepository {
    private let directory: URL

    init(directory: URL = .applicationSupportDirectory.appending(path: "PendingCareCalls", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func save(_ pending: PendingCareCall) throws {
        let folder = folder(for: pending.record.patientId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var noBackup = URLResourceValues()
        noBackup.isExcludedFromBackup = true
        var root = directory
        try root.setResourceValues(noBackup) // 폴더째 백업에서 뺀다
        let stored = Stored(id: pending.id, record: SymptomRecordDTO(symptomRecord: pending.record),
                            symptoms: pending.record.symptoms.map { SymptomEntryDTO(symptomEntry: $0, symptomRecordId: pending.record.id) },
                            complete: pending.complete)
        try JSONEncoder().encode(stored).write(to: url(id: pending.id, patientId: pending.record.patientId),
                                               options: [.atomic, .completeFileProtection])
    }

    func findAll(patientId: UUID) throws -> [PendingCareCall] {
        let folder = folder(for: patientId)
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> PendingCareCall? in
                guard let data = try? Data(contentsOf: url), let stored = try? JSONDecoder().decode(Stored.self, from: data),
                      stored.record.patientId == patientId, // 다른 환자의 기록이 섞여 있으면 올리지 않는다
                      let symptoms = try? stored.symptoms.map({ try $0.toDomain() }) else { return nil }
                return PendingCareCall(id: stored.id, record: stored.record.toDomain(symptoms: symptoms), complete: stored.complete)
            }
            .sorted { $0.record.recordedDate < $1.record.recordedDate }
    }

    func delete(id: UUID, patientId: UUID) throws {
        let url = url(id: id, patientId: patientId)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func folder(for patientId: UUID) -> URL {
        directory.appending(path: patientId.uuidString, directoryHint: .isDirectory)
    }

    private func url(id: UUID, patientId: UUID) -> URL {
        folder(for: patientId).appending(path: "\(id.uuidString).json")
    }

    /// 서버에 올리는 형식(DTO)을 그대로 쓴다
    private struct Stored: Codable {
        let id: UUID
        let record: SymptomRecordDTO
        let symptoms: [SymptomEntryDTO]
        let complete: Bool
    }
}
