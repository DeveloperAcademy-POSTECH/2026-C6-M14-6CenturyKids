#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

enum RecordOverviewKind: String, CaseIterable, Hashable { case pain, symptom
    var title: String { self == .pain ? "통증" : "증상" }
}
struct RecordOverviewSnapshot {
    let pain: Pain?
    let symptom: Symptom?
    struct Pain {
        let averageBefore: Double
        let averageAfter: Double
        let difference: Double
        let previousDayDifference: Double?
    }
    /// presence == .present인 항목 수와 종류만 ViewModel에서 제공합니다.
    /// 부위별 항목은 각각 1건입니다. nil은 집계 미제공, 0은 실제 0건입니다.
    struct Symptom { let presentCount: Int?; let types: [SymptomType] }
}
/// 선택 기간의 증상별 크기와 그 기간의 기록. 크기(weight) 기준은 ViewModel이 정합니다.
/// records는 최신순입니다 (주·월 카드 목록 순서).
struct RecordSymptomDetail { let symptoms: [RecordSymptomItem]; let records: [SymptomRecordDisplay] }
struct RecordSymptomItem: Identifiable {
    let type: SymptomType
    let weight: Double
    var id: SymptomType { type }
}
struct PainRecordDisplay: Identifiable {
    let id: UUID
    let recordedDate: Date
    let painBefore: Int
    let painAfter: Int
}
struct RecordPainDetail { let averageDifference: Double?; let days: [RecordPainDay]; let records: [PainRecordDisplay]? }
struct RecordPainDay { let date: Date; let averageBefore: Double; let averageAfter: Double }
enum RecordDetailContent { case symptom(RecordSymptomDetail), pain(RecordPainDetail) }
enum RecordsAction { case load, moveDay(Int), cancel }
@Observable final class RecordsScreenState {
    var dateLabel = "오늘"
    var snapshot: RecordOverviewSnapshot?
    var loadState: RecordOverviewDisplayState = .unavailable
    @ObservationIgnored var onAction: ((RecordsAction) -> Void)?
}
enum RecordDetailAction {
    case load, movePeriod(Int), selectPeriod(RecordPeriod), edit, cancel
}
/// 날짜 범위·축과 집계값은 호수의 새 ViewModel이 제공합니다. View는 집계를 계산하지 않습니다.
@Observable final class RecordDetailScreenState {
    var kind: RecordOverviewKind
    var period: RecordPeriod = .day
    var periodLabel = "조회 전"
    var rangeLabel = ""
    var calendar = Calendar.current
    var days: [Date] = []
    var content: RecordDetailContent?
    /// 하루 기록 '수정' 버튼 표시 (수정 연결 전까지 false)
    var canEdit = false
    var loadState: RecordOverviewDisplayState = .unavailable
    @ObservationIgnored var onAction: ((RecordDetailAction) -> Void)?
    init(kind: RecordOverviewKind) { self.kind = kind }
}
