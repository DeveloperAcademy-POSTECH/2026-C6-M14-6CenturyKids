import SwiftUI

/// 자체 레이아웃이 있는 카드·아이콘 버튼의 공통 눌림 피드백.
struct AppPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle())
            .opacity(isEnabled && configuration.isPressed ? 0.85 : 1)
    }
}
