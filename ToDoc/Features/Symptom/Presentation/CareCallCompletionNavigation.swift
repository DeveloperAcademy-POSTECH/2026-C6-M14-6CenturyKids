import Foundation

/// 저장 성공 뒤 한 번의 화면 이동만 허용합니다. 날짜가 없으면 임의의 날짜를 만들지 않습니다.
struct CareCallCompletionNavigation {
    private(set) var didNavigate = false

    mutating func beginHome(didSave: Bool) -> Bool {
        begin(didSave: didSave)
    }

    mutating func beginRecord(didSave: Bool, recordedDate: Date?) -> Date? {
        guard let recordedDate, begin(didSave: didSave) else { return nil }
        return recordedDate
    }

    private mutating func begin(didSave: Bool) -> Bool {
        guard didSave, !didNavigate else { return false }
        didNavigate = true
        return true
    }
}
