import SwiftUI

/// 기본 화면은 하단 조작을 고정하고, 큰 글자에서는 질문과 조작 모두에 스크롤로 접근합니다.
struct AppConversationLayout<Content: View, Footer: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) { content(); footer() }
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                VStack(spacing: 0) {
                    ScrollView { content() }
                        .scrollDismissesKeyboard(.interactively)
                    footer()
                }
            }
        }
    }
}
