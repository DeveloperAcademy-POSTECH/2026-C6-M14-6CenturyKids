import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

@MainActor
struct OfflineStorageTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "offline-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func recordsSurviveNewRepositoryInstancesAndKeepPatientBoundaries() async throws {
        let url = try folder()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = LocalFileStore(directory: url)
        let patient = UUID(), other = UUID()
        let now = Date()
        let pain = try PainRecord(id: UUID(), patientId: patient, recordedDate: now.addingTimeInterval(-3700),
                                  location: [.init(bodyPart: .armHand, bodySide: .left, bodyView: .front)], painBefore: 7, painAfter: nil)
        try await LocalPainRepository(store: store).save(entity: pain)
        let reloaded = LocalPainRepository(store: LocalFileStore(directory: url))
        #expect(try await reloaded.findLatestByPatientId(patient)?.id == pain.id)
        #expect(try await reloaded.findByPatientId(other).isEmpty)
        try await reloaded.savePainAfter(recordId: pain.id, painAfter: 3)
        #expect(try await LocalPainRepository(store: store).findById(pain.id)?.painAfter == 3)
        #expect(try await reloaded.findByPatientIdAndDate(patientId: patient, from: pain.recordedDate, to: pain.recordedDate).count == 1)

        let entry = try SymptomEntry(id: UUID(), symptomType: .nauseaVomiting, presence: .present, bodyPart: nil,
                                     bodySide: nil, durationMinutes: nil, occurrenceCount: 2, detail: "어제부터 두 번")
        let symptoms = SymptomRecord(id: UUID(), patientId: patient, recordedDate: now, conditionText: "피곤해요", symptoms: [entry])
        try await LocalSymptomRepository(store: store).save(entity: symptoms)
        let restored = try await LocalSymptomRepository(store: LocalFileStore(directory: url)).findById(symptoms.id)
        #expect(restored?.symptoms.first?.occurrenceCount == 2)
        #expect(restored?.symptoms.first?.detail == "어제부터 두 번")
        #expect(restored?.conditionText == "피곤해요")
        #expect(try await LocalSymptomRepository(store: store).findByPatientId(other).isEmpty)

        let visit = try PrevisitRecord(patientId: patient, selectedDate: now, memo: "질문을 남깁니다", stateOfMind: .slowly)
        try await LocalPrevisitRepository(store: store).save(entity: visit)
        let visits = LocalPrevisitRepository(store: LocalFileStore(directory: url))
        #expect(try await visits.findById(visit.id)?.memo == "질문을 남깁니다")
        #expect(try await visits.findByPatientId(other).isEmpty)
        var changed = visit
        try changed.updateMemo("수정한 질문")
        try await visits.save(entity: changed)
        #expect(try await visits.findByPatientId(patient).count == 1)
        #expect(try await visits.findById(visit.id)?.memo == "수정한 질문")
        try await visits.deleteById(visit.id)
        #expect(try await visits.findById(visit.id) == nil)
    }

    @Test func profileBootstrapsOnceAndRetainsEditsWithoutLogin() async throws {
        let url = try folder()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = LocalFileStore(directory: url)
        try OfflineProfile.prepare(store: store)
        let id = try await LocalAuthRepository().getCurrentUserId()
        var user = try #require(try await LocalUserRepository(store: store).findById(id))
        try user.updateName("오프라인 체험")
        try await LocalUserRepository(store: store).save(user: user)
        try OfflineProfile.prepare(store: LocalFileStore(directory: url))
        #expect(try await LocalPatientRepository(store: store).findById(id)?.user.name == "오프라인 체험")
    }

    @Test func corruptFileFailsInsteadOfPretendingRecordsWereDeleted() async throws {
        let url = try folder()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = LocalFileStore(directory: url)
        let visit = try PrevisitRecord(patientId: UUID(), selectedDate: Date(), memo: nil, stateOfMind: .unsure)
        try await LocalPrevisitRepository(store: store).save(entity: visit)
        let file = url.appending(path: "previsits/\(visit.id).json")
        try Data("invalid".utf8).write(to: file)
        await #expect(throws: (any Error).self) { try await LocalPrevisitRepository(store: store).findById(visit.id) }
        #expect(try String(contentsOf: file, encoding: .utf8) == "invalid")
    }

    @Test func prematureAndStalePainFollowUpCannotOverwriteSavedData() async throws {
        let url = try folder()
        defer { try? FileManager.default.removeItem(at: url) }
        let repo = LocalPainRepository(store: LocalFileStore(directory: url))
        let patient = UUID()
        let record = try PainRecord(id: UUID(), patientId: patient, recordedDate: Date(),
                                    location: [.init(bodyPart: .armHand, bodySide: .left, bodyView: .front)], painBefore: 6, painAfter: nil)
        try await repo.save(entity: record)
        await #expect(throws: LocalStoreError.self) { try await repo.savePainAfter(recordId: record.id, painAfter: 2) }
        #expect(try await repo.findById(record.id)?.painAfter == nil)
    }

    @Test func pendingAnswersSurviveRelaunch() throws {
        let url = try folder()
        defer { try? FileManager.default.removeItem(at: url) }
        let entry = try SymptomEntry(id: UUID(), symptomType: .other, presence: .unknown, bodyPart: nil,
                                     bodySide: nil, durationMinutes: nil, occurrenceCount: nil, detail: "입력하던 말")
        let record = SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: Date(), conditionText: nil, symptoms: [entry])
        let pending = PendingCareCall(id: UUID(), record: record, complete: false)
        try FilePendingCareCallRepository(directory: url).save(pending)
        let restored = try FilePendingCareCallRepository(directory: url).findAll(patientId: record.patientId)
        #expect(restored.first?.record.symptoms.first?.detail == "입력하던 말")
    }

    @Test func pendingReplayIsAtomicAndDoesNotDuplicateFollowUpAnswers() async throws {
        let url = try folder()
        defer { try? FileManager.default.removeItem(at: url) }
        let patient = UUID()
        func record(_ text: String) throws -> SymptomRecord {
            let entry = try SymptomEntry(id: UUID(), symptomType: .other, presence: .present, bodyPart: nil,
                                        bodySide: nil, durationMinutes: nil, occurrenceCount: nil, detail: text)
            return SymptomRecord(id: UUID(), patientId: patient, recordedDate: Date(), conditionText: nil, symptoms: [entry])
        }
        let first = try record("처음 대화"), followUp = try record("중간에 종료된 대화")
        let attempt = UUID()
        let repository = LocalSymptomRepository(store: LocalFileStore(directory: url))
        _ = try repository.savePending(first, attemptID: UUID(), merge: CareCallViewModel.merge)
        _ = try repository.savePending(followUp, attemptID: attempt, merge: CareCallViewModel.merge)
        let reopened = LocalSymptomRepository(store: LocalFileStore(directory: url))
        _ = try reopened.savePending(followUp, attemptID: attempt, merge: CareCallViewModel.merge)
        let saved = try await reopened.findByPatientId(patient)
        #expect(saved.count == 1)
        #expect(saved.first?.symptoms.count == 2)
        #expect(saved.first?.symptoms.contains { $0.detail == "중간에 종료된 대화" } == true)
    }
}
