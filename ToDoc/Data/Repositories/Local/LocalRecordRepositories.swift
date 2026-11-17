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
        var appliedAttempts: [UUID]? = nil
        init(_ value: SymptomRecord) {
            record = SymptomRecordDTO(symptomRecord: value)
            entries = value.symptoms.map { SymptomEntryDTO(symptomEntry: $0, symptomRecordId: value.id) }
        }
        func domain() throws -> SymptomRecord { try record.toDomain(symptoms: entries.map { try $0.toDomain() }) }
    }
    private let store: LocalFileStore
    init(store: LocalFileStore) { self.store = store }
    func save(entity: SymptomRecord) async throws { try store.write(Stored(entity), collection: "symptoms", id: entity.id) }
    /// Store the daily aggregate and its replay receipt in the same atomic file.
    /// Reopening after a crash between save and pending-file deletion cannot duplicate answers.
    func savePending(_ record: SymptomRecord, attemptID: UUID,
                     merge: (SymptomRecord, SymptomRecord) -> SymptomRecord) throws -> UUID {
        try store.locked {
            let all = try store.all(Stored.self, collection: "symptoms").filter { $0.record.patientId == record.patientId }
            if let applied = all.first(where: { $0.appliedAttempts?.contains(attemptID) == true }) { return applied.record.id }
            let previous = all.filter { Calendar.current.isDate($0.record.recordedAt, inSameDayAs: record.recordedDate) }
                .sorted { $0.record.recordedAt > $1.record.recordedAt }.first
            let combined = try previous.map { merge(try $0.domain(), record) } ?? record
            var stored = Stored(combined)
            stored.appliedAttempts = (previous?.appliedAttempts ?? []) + [attemptID]
            try store.write(stored, collection: "symptoms", id: combined.id)
            return combined.id
        }
    }

    func findById(_ id: UUID) async throws -> SymptomRecord? { try store.read(Stored.self, collection: "symptoms", id: id)?.domain() }
    func deleteById(_ id: UUID) async throws { try store.delete(collection: "symptoms", id: id) }
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] {
        try store.all(Stored.self, collection: "symptoms").filter { $0.record.patientId == patientId }
            .map { try $0.domain() }.sorted { $0.recordedDate > $1.recordedDate }
    }
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] {
        try await findByPatientId(patientId).filter { $0.recordedDate >= startDate && $0.recordedDate < endDate }
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
