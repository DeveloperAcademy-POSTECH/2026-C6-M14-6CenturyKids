import Foundation

#if canImport(ToDocDomain)
import ToDocDomain
#endif

/// 시연: 처음 통화에서 7개 중 3개만 랜덤으로 묻고, 나머지 4개는 2개 있음·2개 없음 목데이터로 채운다.
struct DemoCareCallPlan {
    /// 관리자 설정 토글이 저장하는 키. 값이 없으면 켜짐 (시연 빌드 기본값)
    static let enabledKey = "demo.careCallFlow"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    /// 물을 항목 (side_effects.json id)
    let asked: Set<String>
    /// 목데이터로 '있음'을 넣을 항목 (나머지 목데이터는 '없음')
    let mockPresent: Set<String>
    let mocked: [String]

    init(effectIds: [String]) {
        let shuffled = effectIds.shuffled()
        asked = Set(shuffled.prefix(3))
        mocked = Array(shuffled.dropFirst(3))
        mockPresent = Set(mocked.shuffled().prefix(2))
    }

    /// 목데이터를 기록에 더한다. 환자가 답했거나 대화 중 다룬 증상(touched: 통화 기록의 항목 키)은 덮지 않는다
    func filling(_ record: SymptomRecord, touched: Set<String> = []) -> SymptomRecord {
        let answered = Set(record.symptoms.map(\.symptomType))
        let mocks = mocked.compactMap { id -> SymptomEntry? in
            guard let mock = Self.mocks[id], !answered.contains(mock.type), !touched.contains(id) else { return nil }
            let present = mockPresent.contains(id)
            return try? SymptomEntry(id: UUID(), symptomType: mock.type, presence: present ? .present : .absent,
                                     bodyPart: present ? mock.part : nil, bodySide: present ? mock.side : nil,
                                     rawLocationText: present ? mock.location : nil, durationMinutes: nil,
                                     occurrenceCount: present ? mock.count : nil, detail: present ? mock.detail : "아니요")
        }
        return SymptomRecord(id: record.id, patientId: record.patientId, recordedDate: record.recordedDate,
                             conditionText: record.conditionText, symptoms: record.symptoms + mocks)
    }

    private struct Mock {
        let type: SymptomType
        var count: Int?
        var part: BodyPart?
        var side: BodySide?
        var location: String?
        let detail: String
    }

    /// 증상마다 고정한 '있음' 값 (꼬리질문 답 형식은 SymptomRecordConverter와 같게)
    private static let mocks: [String: Mock] = [
        "nausea_vomiting": Mock(type: .nauseaVomiting, count: 2, detail: "구토 횟수: 하루 두 번이요 / 메스꺼움 시작: 어제 저녁부터요"),
        "constipation": Mock(type: .constipation, detail: "사흘 전부터요"),
        "diarrhea": Mock(type: .diarrhea, count: 3, detail: "하루 세 번이요"),
        "stomatitis": Mock(type: .oralPain, detail: "이틀 전부터요"),
        "neuropathy": Mock(type: .numbness, part: .legFoot, side: .both, location: "양쪽 발", detail: "일주일 전부터요"),
        "rash_pruritus": Mock(type: .rashItching, part: .armHand, side: .left, location: "왼팔", detail: "어제부터요"),
        "dehydration_nutrition": Mock(type: .dehydrationNutrition, detail: "평소의 절반 정도요"),
    ]
}
