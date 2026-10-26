import SwiftUI

/// 환자 화면의 공통 여백·바탕색. 기기 safe area는 시스템에 맡깁니다.
extension View {
    func appScreenStyle() -> some View {
        self
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .background(AppColors.background.ignoresSafeArea())
    }
}
