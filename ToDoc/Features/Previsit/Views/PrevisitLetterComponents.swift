import SwiftUI

/// Figma '진료 전 길록 바텀시트 플로우'(753:535)의 지난 기록 화면들이 공용 컴포넌트를 묶어 쓰는 조각입니다.

/// Figma Body 머리: 뒤로 버튼 줄(44) · 가운데 Page Title · 4 여백, 사이 16
struct PrevisitScreenHeader: View {
    let overline: String
    let title: String
    let backLabel: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            AppActions.IconButton(backLabel, icon: Image("DesignSystem/Components/Navigation/Prev"), action: onBack)
                .frame(maxWidth: .infinity, alignment: .leading)
            AppNavigation.PageTitle(title, alignment: .center, overline: overline)
            Color.clear.frame(height: 4)
        }
    }
}

/// 공용 Toast를 2초 띄우고 VoiceOver로도 알립니다
struct PrevisitToast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        AppFeedback.Toast(message)
            .task {
                AccessibilityNotification.Announcement(message).post()
                try? await Task.sleep(for: .seconds(2))
                onDismiss()
            }
    }
}

/// 화면을 어둡게 덮고 가운데에 되돌릴 수 없는 동작을 묻는 공용 Dialog를 띄웁니다
struct PrevisitConfirmDialog: View {
    let title: String
    let message: String
    let destructiveTitle: String
    let cancelTitle: String
    let onDestructive: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().accessibilityHidden(true)
            AppFeedback.Dialog(title, message: message,
                               primary: .init(destructiveTitle, action: onDestructive), primaryKind: .destructive,
                               secondary: .init(cancelTitle, action: onCancel))
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .accessibilityAddTraits(.isModal)
        }
    }
}

extension PrevisitMood {
    /// Figma Avatar 기분 단계 (Calm·Worried·Anxious·NotReady·Unsure)
    var avatar: AppFeedback.Avatar {
        switch self {
        case .candid: AppFeedback.Avatar(mood: .calm)
        case .comfortable: AppFeedback.Avatar(mood: .worried)
        case .slowly: AppFeedback.Avatar(mood: .anxious)
        case .carefully: AppFeedback.Avatar(mood: .notReady)
        case .unsure: AppFeedback.Avatar(mood: .unsure)
        }
    }
}

extension View {
    /// 공용 카드 중 버튼으로만 만들어진 것(Day Record Card·Mood Option)을 읽기 전용으로 씁니다
    func previsitReadOnly() -> some View {
        allowsHitTesting(false).accessibilityRemoveTraits(.isButton)
    }
}
