import Foundation

nonisolated public struct SymptomRecord: Sendable {
    public let id: UUID
    public let recordedDate: Date
    public private(set) var symptoms: [SymptomEntry]

    public init(id: UUID, recordedDate: Date, symptoms: [SymptomEntry]) {
        self.id = id
        self.recordedDate = recordedDate
        var seen = Set<UUID>()
        self.symptoms = symptoms.filter { seen.insert($0.id).inserted }
    }

    public mutating func addSymptomEntry(_ entry: SymptomEntry) {
        guard !symptoms.contains(where: { $0.id == entry.id }) else { return }
        symptoms.append(entry)
    }

    public mutating func removeSymptomEntry(id: UUID) {
        symptoms.removeAll { $0.id == id }
    }
}
