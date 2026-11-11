import Foundation

#if canImport(ToDocDomain)
import ToDocDomain
#endif

/// 시연용 지난 기록. 10/16 앱 첫날·첫 항암, 11/6 두 번째 항암, 11/20 시연(진료) 날.
/// 매번 같은 기록이 나오도록 정한 씨앗으로 만든다.
struct DemoMockData {
    let symptoms: [SymptomRecord]
    let pain: [PainRecord]
    let previsits: [PrevisitRecord]

    /// 기록을 넣는 기간 (끝 날 포함)
    static let firstDay = DateComponents(year: 2026, month: 10, day: 16)
    static let lastDay = DateComponents(year: 2026, month: 11, day: 19)
    /// 진료(항암) 날
    static let doseDays = [DateComponents(year: 2026, month: 10, day: 16), DateComponents(year: 2026, month: 11, day: 6)]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    /// 넣는 기간 [시작 날 0시, 끝 날 다음 날 0시)
    static var range: (start: Date, end: Date) {
        let start = calendar.date(from: firstDay)!
        return (start, calendar.date(byAdding: .day, value: 1, to: calendar.date(from: lastDay)!)!)
    }

    init(patientId: UUID) throws {
        let calendar = Self.calendar
        var random = SeededRandom(seed: 20261120)
        let doses = Self.doseDays.map { calendar.date(from: $0)! }
        let (start, end) = Self.range
        var days: [Date] = []
        var day = start
        while day < end { days.append(day); day = calendar.date(byAdding: .day, value: 1, to: day)! }

        symptoms = try days.map { day in
            let dose = doses.last { $0 <= day }!
            let cycle = doses.firstIndex(of: dose)! + 1
            let n = calendar.dateComponents([.day], from: dose, to: day).day!
            // 첫날(10/16)은 항암 전 아침에 남긴 기록이라 아무 증상이 없다
            let morningBeforeDose = cycle == 1 && n == 0
            let time = morningBeforeDose ? (8, 30) : (20, random.next(in: 0...40))
            let recordedAt = calendar.date(bySettingHour: time.0, minute: time.1, second: 0, of: day)!
            let entries = morningBeforeDose ? try Self.absentAll() : try Self.entries(cycle: cycle, n: n)
            return SymptomRecord(id: UUID(), patientId: patientId, recordedDate: recordedAt,
                                 conditionText: Self.condition(cycle: cycle, n: n, morningBeforeDose: morningBeforeDose),
                                 symptoms: entries)
        }

        // 통증: 주마다 2~3일, 먹기 전 6~9점 → 1시간 뒤 4~6점 낮아짐
        var painRecords: [PainRecord] = []
        var weekStart = start
        while weekStart < end {
            let weekDays = days.filter { $0 >= weekStart && $0 < calendar.date(byAdding: .day, value: 7, to: weekStart)! }
            let picked = random.shuffled(weekDays).prefix(random.next(in: 2...3)).sorted()
            for day in picked {
                let before = random.next(in: 6...9)
                let after = before - random.next(in: 4...min(6, before))
                let at = calendar.date(bySettingHour: random.next(in: 10...20), minute: random.next(in: 0...59), second: 0, of: day)!
                let locations = Array(random.shuffled(Self.painPlaces).prefix(random.next(in: 1...2)))
                painRecords.append(try PainRecord(id: UUID(), patientId: patientId, recordedDate: at, location: locations,
                                                  painBefore: before, painAfter: after))
            }
            weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        }
        pain = painRecords

        func at(_ month: Int, _ dayOfMonth: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth, hour: hour, minute: minute))!
        }
        previsits = [
            try PrevisitRecord(id: UUID(), patientId: patientId,
                               selectedDate: at(10, 16, 0, 0),
                               memo: "오늘 첫 항암이라 많이 긴장돼요. 집에서 구토나 설사가 심해지면 어떻게 해야 하는지, 언제 병원에 연락해야 하는지 알고 싶어요.",
                               stateOfMind: .slowly, submittedAt: at(10, 16, 9, 30)),
            try PrevisitRecord(id: UUID(), patientId: patientId,
                               selectedDate: at(11, 5, 0, 0),
                               memo: "지난 항암 뒤 사흘 정도 구토와 설사가 심했고, 일주일쯤 입안이 헐어서 먹기 힘들었어요. 손끝 저림이 계속돼서 걱정돼요. 이번에는 미리 할 수 있는 게 있을까요?",
                               stateOfMind: .comfortable, submittedAt: at(11, 6, 9, 0)),
        ]
    }

    private static let painPlaces = [
        BodyLocation(bodyPart: .abdomen, bodySide: .center, bodyView: .front),
        BodyLocation(bodyPart: .backLowerBack, bodySide: .center, bodyView: .back),
        BodyLocation(bodyPart: .headFace, bodySide: .center, bodyView: .front),
    ]

    private static func entry(_ type: SymptomType, count: Int? = nil, part: BodyPart? = nil, side: BodySide? = nil,
                              location: String? = nil, detail: String) throws -> SymptomEntry {
        try SymptomEntry(id: UUID(), symptomType: type, presence: .present, bodyPart: part, bodySide: side,
                         rawLocationText: location, durationMinutes: nil, occurrenceCount: count, detail: detail)
    }

    private static func absent(_ type: SymptomType) throws -> SymptomEntry {
        try SymptomEntry(id: UUID(), symptomType: type, presence: .absent, bodyPart: nil, bodySide: nil,
                         durationMinutes: nil, occurrenceCount: nil, detail: "없어요")
    }

    private static let allTypes: [SymptomType] = [.nauseaVomiting, .constipation, .diarrhea, .oralPain, .numbness, .rashItching, .dehydrationNutrition]

    private static func absentAll() throws -> [SymptomEntry] { try allTypes.map(absent) }

    /// 항암 n일 뒤(0 = 항암 날) 증상. 1회차보다 2회차 저림이 늘어난다
    private static func entries(cycle: Int, n: Int) throws -> [SymptomEntry] {
        var present: [SymptomEntry] = []
        let vomit = cycle == 1 ? [1: 3, 2: 2, 3: 1] : [0: 1, 1: 3, 2: 2, 3: 1]
        if let count = vomit[n] {
            present.append(try entry(.nauseaVomiting, count: count,
                                     detail: "구토 횟수: 하루 \(count)번이요 / 메스꺼움 시작: 항암 맞은 날 저녁부터요"))
        }
        let loose = cycle == 1 ? [3: 3, 4: 4, 5: 2] : [2: 2, 3: 3, 4: 2]
        if let count = loose[n] { present.append(try entry(.diarrhea, count: count, detail: "하루 \(count)번이요")) }
        if (cycle == 1 ? 7...8 : 6...7).contains(n) { present.append(try entry(.constipation, detail: "이틀째 변을 못 봤어요")) }
        if (cycle == 1 ? 5...10 : 4...9).contains(n) { present.append(try entry(.oralPain, detail: "입안이 헐어서 따가워요")) }
        if cycle == 1 ? n >= 5 : true {
            present.append(try entry(.numbness, part: .armHand, side: .both, location: "양손", detail: "손끝이 저려요"))
        }
        if cycle == 2 && n >= 7 {
            present.append(try entry(.numbness, part: .legFoot, side: .both, location: "양쪽 발", detail: "발끝도 저리기 시작했어요"))
        }
        if (cycle == 1 ? [8, 9] : [7]).contains(n) {
            present.append(try entry(.rashItching, part: .armHand, side: .left, location: "왼팔", detail: "팔에 붉은 반점이 생기고 가려워요"))
        }
        if (1...5).contains(n) {
            present.append(try entry(.dehydrationNutrition, detail: n <= 3 ? "평소의 3분의 1 정도 먹었어요" : "평소의 절반 정도 먹었어요"))
        }
        let had = Set(present.map(\.symptomType))
        return try present + allTypes.filter { !had.contains($0) }.map(absent)
    }

    private static func condition(cycle: Int, n: Int, morningBeforeDose: Bool) -> String {
        if morningBeforeDose { return "오늘 첫 항암 맞으러 가요. 아직은 괜찮아요" }
        switch n {
        case 0: return "항암 맞고 와서 기운이 없어요"
        case 1...3: return "속이 울렁거리고 많이 힘들어요"
        case 4...5: return "어제보다는 조금 나아요"
        case 6...10: return "입안이 헐어서 먹기가 힘들어요"
        case 11...15: return "많이 좋아졌어요"
        default: return cycle == 2 && n >= 7 ? "컨디션은 괜찮은데 손발이 저려요" : "컨디션 괜찮아요"
        }
    }
}

/// 매번 같은 수열을 내는 난수 (SplitMix64)
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var items = items
        for i in items.indices.reversed() where i > 0 { items.swapAt(i, next(in: 0...i)) }
        return items
    }
}
