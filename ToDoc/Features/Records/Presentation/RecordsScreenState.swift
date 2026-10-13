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
    struct Symptom { let averageSeverity: Double?; let types: [SymptomType] }
}
struct RecordSymptomDetail { let averageSeverity: Double?; let days: [RecordSymptomDay] }
struct RecordSymptomDay { let date: Date; let averageSeverity: Double?; let record: SymptomRecordDisplay? }
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
    case load, movePeriod(Int), selectPeriod(RecordPeriod), cancel
    case saveScores(UUID, [UUID: String])
}
/// 날짜 범위·축과 집계값은 호수의 새 ViewModel이 제공합니다. View는 평균을 계산하지 않습니다.
@Observable final class RecordDetailScreenState {
    var kind: RecordOverviewKind
    var period: RecordPeriod = .day
    var periodLabel = "조회 전"
    var rangeLabel = ""
    var calendar = Calendar.current
    var days: [Date] = []
    var content: RecordDetailContent?
    var loadState: RecordOverviewDisplayState = .unavailable
    var isEditing = false
    var scoreTexts: [UUID: String] = [:]
    var isSaving = false
    var canSave = false
    var errorMessage: String?
    @ObservationIgnored var onAction: ((RecordDetailAction) -> Void)?
    init(kind: RecordOverviewKind) { self.kind = kind }
}
