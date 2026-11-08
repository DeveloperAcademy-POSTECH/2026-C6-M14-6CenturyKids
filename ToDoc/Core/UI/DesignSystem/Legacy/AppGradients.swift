import SwiftUI

/// 채우기가 아닌 버튼 바깥선에 사용하는 위→아래 그라데이션입니다.
enum AppGradients {
    static let primaryBorder = border("PrimaryBorderTop", "PrimaryBorderTop")
    static let disabledBorder = border("DisabledBorderTop", "DisabledBorderBottom")
    static let backBorder = border("BackBorderTop", "BackBorderTop")

    private static func border(_ top: String, _ bottom: String) -> LinearGradient {
        LinearGradient(
            colors: [Color("DesignSystem/\(top)"), Color("DesignSystem/\(bottom)")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
