import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 기존 저장 기록을 날짜 카드로 표시합니다. 기록을 만들거나 저장하지 않습니다.
enum PrevisitRecordedDays {
    enum Issue: Error { case patientMismatch }

    static func make(pain: [PainRecord], symptoms: [SymptomRecord], patientID: UUID,
                     calendar: Calendar = .current) throws -> [PrevisitDay] {
        guard pain.allSatisfy({ $0.patientId == patientID }),
              symptoms.allSatisfy({ $0.patientId == patientID }) else { throw Issue.patientMismatch }
        let pains = Dictionary(grouping: pain) { calendar.startOfDay(for: $0.recordedDate) }
        let symptomDays = Dictionary(grouping: symptoms) { calendar.startOfDay(for: $0.recordedDate) }
        let dates = Set(pains.keys).union(symptomDays.keys).sorted(by: >)
        return dates.map { date in
            let dailyPain = (pains[date] ?? []).sorted {
                $0.recordedDate != $1.recordedDate ? $0.recordedDate < $1.recordedDate : $0.id.uuidString < $1.id.uuidString
            }
            let dailySymptoms = (symptomDays[date] ?? []).sorted {
                $0.recordedDate != $1.recordedDate ? $0.recordedDate < $1.recordedDate : $0.id.uuidString < $1.id.uuidString
            }
            return PrevisitDay(
                id: "recorded-day-\(date.timeIntervalSince1970)",
                dateLabel: "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))",
                weekday: calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1],
                entries: dailySymptoms.flatMap { symptomLines($0) } + dailyPain.map { painLine($0) },
                recordedDate: date, painRecordIDs: dailyPain.map(\.id), symptomRecordIDs: dailySymptoms.map(\.id)
            )
        }
    }

    private static func painLine(_ record: PainRecord) -> String {
        let locations = record.location.map { location in
            [location.bodySide == .unspecified ? nil : location.bodySide.displayName, location.bodyPart.displayName]
                .compactMap { $0 }.joined(separator: " ")
        }.joined(separator: ", ")
        return "\(locations) 통증 \(record.painBefore) → \(record.painAfter)"
    }

    private static func symptomLines(_ record: SymptomRecord) -> [String] {
        var lines = text(record.conditionText).map { [$0] } ?? []
        let present = record.symptoms.filter { $0.presence == .present }
        let entries = present.isEmpty ? record.symptoms : present
        if entries.isEmpty { lines.append("증상 항목 없이 기록") }
        lines += entries.map { entry in
            var values = [entry.symptomType.displayName]
            switch entry.presence {
            case .present: break
            case .absent: values.append("증상 없음으로 기록")
            case .unknown: values.append("증상 유무를 모름으로 기록")
            }
            if let count = entry.occurrenceCount { values.append("\(count)회") }
            if let duration = entry.durationMinutes { values.append("\(duration)분") }
            let location = text(entry.rawLocationText) ?? entry.bodyPart.map { part in
                [entry.bodySide == .unspecified ? nil : entry.bodySide?.displayName, part.displayName]
                    .compactMap { $0 }.joined(separator: " ")
            }
            if let location { values.append(location) }
            if let detail = text(entry.detail) { values.append(detail) }
            return values.joined(separator: " · ")
        }
        return lines
    }

    /// 빈 문장만 제외하고, 사용자가 말한 원문의 공백·줄바꿈은 바꾸지 않습니다.
    private static func text(_ value: String?) -> String? {
        value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }
}
