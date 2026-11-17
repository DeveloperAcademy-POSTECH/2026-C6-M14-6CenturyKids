import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

final class LocalPainRepository: PainRepository {
    private struct Stored: Codable {
        let record: PainRecordDTO
        let locations: [PainLocationDTO]
        init(_ value: PainRecord) {
            record = PainRecordDTO(painRecord: value)
            locations = value.location.map { PainLocationDTO(painRecordId: value.id, bodyLocation: $0) }
        }
        func domain() throws -> PainRecord { try record.toDomain(locations: locations.map { try $0.toDomain() }) }
    }
    private let store: LocalFileStore
    private let now: () -> Date
    init(store: LocalFileStore, now: @escaping () -> Date = Date.init) { self.store = store; self.now = now }
    func save(entity: PainRecord) async throws { try store.write(Stored(entity), collection: "pain", id: entity.id) }
    func findById(_ id: UUID) async throws -> PainRecord? { try store.read(Stored.self, collection: "pain", id: id)?.domain() }
    func deleteById(_ id: UUID) async throws { try store.delete(collection: "pain", id: id) }
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] { try records(patientId) }
    private func records(_ patientId: UUID) throws -> [PainRecord] {
        try store.all(Stored.self, collection: "pain").filter { $0.record.patientId == patientId }
            .map { try $0.domain() }.sorted { $0.recordedDate > $1.recordedDate }
    }
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [PainRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
        return try records(patientId).filter { $0.recordedDate >= start && $0.recordedDate < end }
            .sorted { $0.recordedDate < $1.recordedDate }
    }
    func findLatestByPatientId(_ patientId: UUID) async throws -> PainRecord? { try records(patientId).first }
    func savePainAfter(recordId: UUID, painAfter: Int) async throws {
        try store.locked {
            guard let record = try store.read(Stored.self, collection: "pain", id: recordId)?.domain() else {
                throw LocalStoreError.missingRecord
            }
            guard try records(record.patientId).first?.id == recordId,
                  now() >= record.recordedDate.addingTimeInterval(3600) else { throw LocalStoreError.followUpNotReady }
            let updated = try PainRecord(id: record.id, patientId: record.patientId, recordedDate: record.recordedDate,
                                         location: record.location, painBefore: record.painBefore, painAfter: painAfter)
            try store.write(Stored(updated), collection: "pain", id: recordId)
        }
    }
}

final class LocalSymptomRepository: SymptomRepository {
    private struct Stored: Codable {
        let record: SymptomRecordDTO
        let entries: [SymptomEntryDTO]
        init(_ value: SymptomRecord) {
            record = SymptomRecordDTO(symptomRecord: value)
            entries = value.symptoms.map { SymptomEntryDTO(symptomEntry: $0, symptomRecordId: value.id) }
        }
        func domain() throws -> SymptomRecord { try record.toDomain(symptoms: entries.map { try $0.toDomain() }) }
    }
    private let store: LocalFileStore
    init(store: LocalFileStore) { self.store = store }
    func save(entity: SymptomRecord) async throws { try store.write(Stored(entity), collection: "symptoms", id: entity.id) }
    func findById(_ id: UUID) async throws -> SymptomRecord? { try store.read(Stored.self, collection: "symptoms", id: id)?.domain() }
    func deleteById(_ id: UUID) async throws { try store.delete(collection: "symptoms", id: id) }
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] {
        try store.all(Stored.self, collection: "symptoms").filter { $0.record.patientId == patientId }
            .map { try $0.domain() }.sorted { $0.recordedDate > $1.recordedDate }
    }
    /// 서버처럼 날짜(yyyy-MM-dd)로 비교합니다. 시작일은 넣고 끝일은 빼며, 오래된 순으로 돌려줍니다.
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] {
        let start = DateOnlyFormatter.string(from: startDate)
        let end = DateOnlyFormatter.string(from: endDate)
        return try store.all(Stored.self, collection: "symptoms")
            .filter { $0.record.patientId == patientId && $0.record.date >= start && $0.record.date < end }
            .map { try $0.domain() }.sorted { $0.recordedDate < $1.recordedDate }
    }
}

final class LocalPrevisitRepository: PrevisitRepository {
    private let store: LocalFileStore
    init(store: LocalFileStore) { self.store = store }
    func save(entity: PrevisitRecord) async throws { try store.write(PrevisitRecordDTO(previsitRecord: entity), collection: "previsits", id: entity.id) }
    func findById(_ id: UUID) async throws -> PrevisitRecord? { try store.read(PrevisitRecordDTO.self, collection: "previsits", id: id)?.toDomain() }
    func deleteById(_ id: UUID) async throws { try store.delete(collection: "previsits", id: id) }
    func findByPatientId(_ patientId: UUID) async throws -> [PrevisitRecord] {
        try store.all(PrevisitRecordDTO.self, collection: "previsits").filter { $0.patientId == patientId }
            .map { try $0.toDomain() }.sorted { $0.submittedAt > $1.submittedAt }
    }
    func findByPatientIdAndDate(patientId: UUID, date: Date) async throws -> PrevisitRecord? {
        try await findByPatientId(patientId).first { Calendar.current.isDate($0.submittedAt, inSameDayAs: date) }
    }
}
