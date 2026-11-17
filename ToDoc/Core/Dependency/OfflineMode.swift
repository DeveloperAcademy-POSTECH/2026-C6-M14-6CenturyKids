import Foundation

/// 관리자 설정의 "기기에만 저장" 토글입니다.
/// 켜져 있으면 로그인 없이 고정된 체험자로 들어가 기록을 기기에만 저장하고, 기기에 있는 기록만 보여 줍니다.
nonisolated enum OfflineMode {
    /// 관리자 설정 토글이 저장하는 키. 값이 없으면 꺼짐
    static let enabledKey = "demo.offlineMode"
    /// 앱을 켤 때 읽은 값. 저장소는 앱을 켤 때 한 번 고르므로, 토글을 바꿔도 다시 켜기 전에는 그대로입니다.
    static let isOn = UserDefaults.standard.bool(forKey: enabledKey)
}
