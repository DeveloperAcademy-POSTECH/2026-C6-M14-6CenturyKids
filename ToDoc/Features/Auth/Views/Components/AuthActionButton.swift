import SwiftUI

/// 인증 요청 중 표시만 덧붙이고 공용 디자인 시스템의 버튼 규격을 재사용합니다.
struct AuthActionButton: View {
    let title: String
    var isLoading = false
    var loadingTitle: String
    let action: () -> Void

    init(_ title: String, isLoading: Bool = false, loadingTitle: String = "처리 중이에요", action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.loadingTitle = loadingTitle
        self.action = action
    }

    var body: some View {
        AppActions.Button(isLoading ? loadingTitle : title, action: action)
            .overlay(alignment: .leading) {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.Semantic.Text.onPrimary)
                        .padding(.leading, 24)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityValue(isLoading ? "처리 중" : "")
    }
}
