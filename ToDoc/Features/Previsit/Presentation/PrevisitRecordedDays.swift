import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 기존 저장 기록을 날짜 카드로 표시합니다. 기록을 만들거나 저장하지 않습니다.
enum PrevisitRecordedDays {
    enum Issue: Error { case patientMismatch }

    /// 오늘과 이전 29일의 범위. 끝은 내일 0시이며 포함하지 않습니다.
    static func selectionRange(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -29, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// 작성할 때 선택할 수 있는 날짜. 지난 기록 조회에는 적용하지 않습니다.
    static func selectableDays(_ days: [PrevisitDay], now: Date = .now,
                               calendar: Calendar = .current) -> [PrevisitDay] {
        guard let range = selectionRange(now: now, calendar: calendar) else { return [] }
        return days.filter { day in
            guard let date = day.recordedDate else { return false }
            return date >= range.start && date < range.end
        }
    }

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
            // 악화된 기록은 복용 후 통증이 가장 높은 것, 그 외에는 감소 폭이 가장 작은 것.
            // 동률이면 복용 후 통증, 기록 시각 순으로 우선합니다.
            let complete = dailyPain.filter { $0.painAfter != nil }
            let increased = complete.filter { $0.painAfter! > $0.painBefore }
            let badgePain = increased.max {
                if $0.painAfter != $1.painAfter { return $0.painAfter! < $1.painAfter! }
                return $0.recordedDate < $1.recordedDate
            } ?? complete.min {
                let leftReduction = $0.painBefore - $0.painAfter!
                let rightReduction = $1.painBefore - $1.painAfter!
                if leftReduction != rightReduction { return leftReduction < rightReduction }
                if $0.painAfter != $1.painAfter { return $0.painAfter! > $1.painAfter! }
                return $0.recordedDate > $1.recordedDate
            } ?? dailyPain.max {
                if $0.painBefore != $1.painBefore { return $0.painBefore < $1.painBefore }
                return $0.recordedDate < $1.recordedDate
            }
            return PrevisitDay(
                id: "recorded-day-\(date.timeIntervalSince1970)",
                dateLabel: "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))",
                weekday: calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1],
                entries: dailySymptoms.flatMap { symptomLines($0) } + dailyPain.map { painLine($0) },
                recordedDate: date, painRecordIDs: dailyPain.map(\.id), symptomRecordIDs: dailySymptoms.map(\.id),
                painBefore: badgePain?.painBefore, painAfter: badgePain?.painAfter,
                symptomCount: dailySymptoms.flatMap(\.symptoms).filter { $0.presence == .present }.count
            )
        }
    }

    private static func painLine(_ record: PainRecord) -> String {
        let locations = record.location.map { location in
            [location.bodySide == .unspecified ? nil : location.bodySide.displayName, location.bodyPart.displayName]
                .compactMap { $0 }.joined(separator: " ")
        }.joined(separator: ", ")
        let after = record.painAfter.map { String($0) } ?? "사후 통증 미기록"
        return "\(locations) 통증 \(record.painBefore) → \(after)"
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
