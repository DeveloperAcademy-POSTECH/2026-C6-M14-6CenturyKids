//
//  SymptomRecord+Edit.swift
//  ToDoc
//
//  Created by seokho on 10/21/26.
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation

/// 환자가 증상 카드를 고치거나 지울 때의 규칙. 케어콜 요약과 기록 상세가 같이 쓴다
extension SymptomRecord {
    /// 고친 횟수·지속 시간·내용을 검증해 반영한다. 비운 칸은 값 없음. 숫자가 아니거나 범위를 벗어나면 SymptomValueError
    func editingEntry(_ id: UUID, with input: SymptomEntryEditInput) throws -> SymptomRecord {
        guard let entry = symptoms.first(where: { $0.id == id }) else { return self }
        let detail = input.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let edited = try SymptomEntry(
            id: entry.id, symptomType: entry.symptomType, presence: entry.presence, bodyPart: entry.bodyPart, bodySide: entry.bodySide,
            rawLocationText: entry.rawLocationText, durationMinutes: try Self.number(input.durationText, else: .invalidDuration),
            occurrenceCount: try Self.number(input.occurrenceText, else: .invalidOccurrenceCount), detail: detail.isEmpty ? nil : detail)
        return replacingSymptoms(symptoms.map { $0.id == id ? edited : $0 })
    }

    /// 환자가 지운 증상은 '없음'으로 바꾸고 의료진이 알 수 있게 검토 필요로 남긴다.
    /// 같은 증상의 다른 부위 항목이 남아 있으면 그 항목만 뺀다
    func removingEntry(_ id: UUID) -> SymptomRecord {
        guard let index = symptoms.firstIndex(where: { $0.id == id }) else { return self }
        var symptoms = symptoms
        let removed = symptoms.remove(at: index)
        if !symptoms.contains(where: { $0.symptomType == removed.symptomType && $0.presence == .present }) {
            // 원래 내용에 이미 검토 필요 표시가 있으면 한 번만 쓴다
            let original = removed.detail.map { $0.hasPrefix("[검토 필요] ") ? String($0.dropFirst("[검토 필요] ".count)) : $0 }
            let note = ["[검토 필요] 환자가 지움", original].compactMap(\.self).joined(separator: ": ")
            if let absent = try? SymptomEntry(id: UUID(), symptomType: removed.symptomType, presence: .absent, bodyPart: nil, bodySide: nil,
                                              durationMinutes: nil, occurrenceCount: nil,
                                              detail: String(note.prefix(SymptomEntry.detailLimit))) {
                symptoms.insert(absent, at: index)
            }
        }
        return replacingSymptoms(symptoms)
    }

    func replacingSymptoms(_ symptoms: [SymptomEntry]) -> SymptomRecord {
        SymptomRecord(id: id, patientId: patientId, recordedDate: recordedDate, conditionText: conditionText, symptoms: symptoms)
    }

    /// 고친 값을 못 받은 이유 (화면에 그대로 보여 준다)
    static func editErrorMessage(_ error: Error) -> String {
        switch error {
        case SymptomValueError.invalidDuration: "지속 시간은 10분에서 1440분 사이 숫자로 입력해 주세요."
        case SymptomValueError.invalidOccurrenceCount: "횟수는 1에서 100 사이 숫자로 입력해 주세요."
        case SymptomValueError.detailTooLong: "내용은 \(SymptomEntry.detailLimit)자까지 쓸 수 있어요."
        default: "입력한 내용을 확인해 주세요."
        }
    }

    private static func number(_ text: String, else error: SymptomValueError) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        guard let value = Int(trimmed) else { throw error }
        return value
    }
}
