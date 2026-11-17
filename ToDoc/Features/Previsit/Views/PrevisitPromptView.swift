import SwiftUI

/// 완료 표시는 전송 결과를 받은 부모가 선택합니다. 이 View는 저장/전송하지 않습니다.
/// 시작 안내는 홈의 바텀시트(Figma 02)로, 전송 완료는 가운데 팝업으로 그립니다.
/// 완료 상태의 '보낸 기록 보기'는 onStart로 부모가 이동을 정합니다.
struct PrevisitPromptView: View {
    var completedDraft: PrevisitDraft?
    var startTitle: String?
    /// 오늘 보낸 기록이 있으면 작성 대신 해당 기록을 엽니다.
    var onViewToday: (() -> Void)?
    var onStart: () -> Void = {}
    var onRecords: () -> Void = {}
    var onClose: () -> Void = {}
    var onDiscard: (() -> Void)?
    @State private var sheetHeight: CGFloat = 480

    var body: some View {
        if completedDraft == nil {
            sheet.fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
                .presentationDetents([.height(sheetHeight)])
                .presentationDragIndicator(.hidden) // Figma 손잡이를 직접 그립니다
                .presentationCornerRadius(40)
                .presentationBackground(AppColors.Semantic.Background.surface) // 기본 시트는 반투명이라 뒤 화면이 비친다
        } else {
            ZStack {
                AppColors.Previsit.dim.ignoresSafeArea().accessibilityHidden(true)
                ScrollView {
                    completionDialog
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.vertical, 24)
                }.scrollBounceBehavior(.basedOnSize).defaultScrollAnchor(.center)
            }
        }
    }

    /// Figma 02 시트(782:1411): 손잡이 · 제목과 닫기 · 버튼 두 개
    private var sheet: some View {
        VStack(spacing: 20) {
            Capsule().fill(AppColors.Semantic.Border.default).frame(width: 36, height: 5).accessibilityHidden(true)
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(width: 44, height: 44)
                AppNavigation.PageTitle(onViewToday == nil ? "진료 받기 전 대기중인가요?" : "오늘 기록을 보냈어요",
                                        alignment: .center, overline: "진료 전 기록하기")
                // Figma 아이콘이 아직 자리만 있어 뒤로가기(Prev)와 같은 굵기·크기로 그린 닫기 아이콘을 씁니다
                AppActions.IconButton("닫기", icon: Image("PrevisitClose"), action: onClose)
            }
            // 홈의 통증 기록하기·증상 대화하기 카드 간격(14)과 맞춤
            VStack(spacing: 14) {
                if let onViewToday {
                    AppActions.Button("오늘 보낸 기록 보기", action: onViewToday)
                        .accessibilityIdentifier("previsit.viewToday")
                } else {
                    AppActions.Button(startTitle ?? "진료 전 기록하기", action: onStart)
                        .accessibilityIdentifier("previsit.start")
                }
                AppActions.Button("지난 기록 전체보기", kind: .secondary, action: onRecords)
                    .accessibilityIdentifier("previsit.records")
            }
            if let onDiscard {
                Button("작성 중인 내용 지우기", role: .destructive, action: onDiscard)
                    .appTypography(.label).accessibilityIdentifier("previsit.discard")
            }
        }.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 40)
    }

    private var completionDialog: some View {
        AppFeedback.Dialog(
            "기록이 완료되었습니다",
            message: "의사 선생님께 전달 되었어요",
            primary: .init("보낸 기록 보기", action: onStart),
            secondary: .init("닫기", action: onClose)
        )
        .accessibilityAddTraits(.isModal)
    }
}
