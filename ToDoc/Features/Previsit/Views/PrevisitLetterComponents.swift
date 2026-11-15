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

extension StateOfMind {
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

extension StateOfMind {
    /// 목록·상세에 쓰는 기분 한마디
    var historyLabel: String {
        switch self {
        case .candid: "안정돼요"
        case .comfortable: "긴장돼요"
        case .slowly: "걱정돼요"
        case .carefully: "불안해요"
        case .unsure: "잘 모르겠어요"
        }
    }

    /// 기분 수정 시트 순서
    static let editOrder: [StateOfMind] = [.candid, .comfortable, .slowly, .carefully, .unsure]
}

/// Figma 기분 수정 시트의 얼굴(40×40 원 안에 기분 슬라이더 그림을 93×62로 잘라 넣음)
struct PrevisitMoodFace: View {
    let mood: StateOfMind

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 40, height: 40)
            .overlay(alignment: .topLeading) {
                Image(artwork)
                    .resizable()
                    .frame(width: 93, height: 62)
                    .offset(x: mood == .unsure ? -28 : -26, y: 1)
            }
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private var artwork: String {
        switch self.mood {
        case .candid: "PrevisitMoodCalm"
        case .comfortable: "PrevisitMoodTense"
        case .slowly: "PrevisitMoodWorried"
        case .carefully: "PrevisitMoodAnxiousOverlay"
        case .unsure: "PrevisitMoodUnsure"
        }
    }

    private var color: Color {
        switch self.mood {
        case .candid: AppColors.Semantic.Avatar.calm
        case .comfortable: AppColors.Semantic.Avatar.worried
        case .slowly: AppColors.Semantic.Avatar.anxious
        case .carefully: AppColors.Semantic.Avatar.notReady
        case .unsure: AppColors.Semantic.Avatar.unsure
        }
    }
}

/// Figma Bottom Sheet Header: 손잡이 · 가운데 제목 · 오른쪽 확인(체크) 버튼
struct PrevisitSheetHeader: View {
    let title: String
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(AppColors.Semantic.Border.default).frame(width: 36, height: 5).accessibilityHidden(true)
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(width: 44, height: 44)
                AppNavigation.PageTitle(title, alignment: .center)
                AppActions.IconButton("수정 완료", icon: Image("PrevisitCheck"),
                                      fill: AppColors.Semantic.Background.selected, action: onConfirm)
                    .accessibilityIdentifier("previsitEdit.confirm")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
}

extension View {
    /// 공용 카드 중 버튼으로만 만들어진 것(Day Record Card·Mood Option)을 읽기 전용으로 씁니다
    func previsitReadOnly() -> some View {
        allowsHitTesting(false).accessibilityRemoveTraits(.isButton)
    }
}
