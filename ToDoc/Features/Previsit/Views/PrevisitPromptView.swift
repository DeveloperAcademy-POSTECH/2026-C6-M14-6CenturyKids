import SwiftUI

/// 완료 표시는 전송 결과를 받은 부모가 선택합니다. 이 View는 저장/전송하지 않습니다.
/// 시작 안내는 홈의 바텀시트(Figma 02)로, 전송 완료는 가운데 팝업으로 그립니다.
/// 완료 상태의 '기록 보러가기'는 onStart로 부모가 이동을 정합니다.
struct PrevisitPromptView: View {
    var completedDraft: PrevisitDraft?
    var doctorName = "선생님"
    var patientName = ""
    var startTitle: String?
    /// 오늘 이미 보냈으면 false: 작성 버튼을 막고 지난 기록 보기만 남깁니다
    var canStart = true
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
                AppColors.Previsit.dim.ignoresSafeArea()
                ScrollView {
                    card.padding(24).appSurface(.previsitPrompt)
                        .padding(.horizontal, AppSpacing.screenHorizontal).padding(.vertical, 24)
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
                AppNavigation.PageTitle("진료 받기 전 대기중인가요?", alignment: .center, overline: "진료 전 기록하기")
                // Figma 아이콘이 아직 자리만 있어 뒤로가기(Prev)와 같은 굵기·크기로 그린 닫기 아이콘을 씁니다
                AppActions.IconButton("닫기", icon: Image("PrevisitClose"), action: onClose)
            }
            // 홈의 통증 기록하기·증상 대화하기 카드 간격(14)과 맞춤
            VStack(spacing: 14) {
                AppActions.Button(canStart ? startTitle ?? "진료 전 기록하기" : "오늘 기록은 이미 보냈어요", action: onStart)
                    .disabled(!canStart).accessibilityIdentifier("previsit.start")
                AppActions.Button("지난 기록 전체보기", kind: .secondary, action: onRecords)
                    .accessibilityIdentifier("previsit.records")
            }
            if let onDiscard {
                Button("작성 중인 내용 지우기", role: .destructive, action: onDiscard)
                    .appTypography(.label).accessibilityIdentifier("previsit.discard")
            }
        }.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 40)
    }

    /// 전송 완료 팝업 카드
    private var card: some View {
        VStack(spacing: AppSpacing.section) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(AppColors.Previsit.close)
                    .frame(width: 44, height: 28)
            }.accessibilityLabel("닫기").frame(maxWidth: .infinity, alignment: .trailing).padding(.top, -12).padding(.trailing, -10)
            VStack(spacing: AppSpacing.tight) {
                Text("진료 전 기록하기").appTextStyle(.caption).foregroundStyle(AppColors.Previsit.promptCaption)
                Text(completedDraft == nil ? "진료 받기 전 대기중인가요?" : "전송이 완료 되었습니다")
                    .appTextStyle(.heading).foregroundStyle(AppColors.Previsit.promptTitle)
            }.multilineTextAlignment(.center)
            PrevisitDoctorAvatar(mood: completedDraft?.mood ?? .candid, size: completedDraft == nil ? 120 : 80)
            if let draft = completedDraft {
                VStack(alignment: .leading, spacing: 28) {
                    Text("To \(doctorName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
                    Text(draft.letter).appFont(.body).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let mood = draft.mood {
                        HStack(spacing: AppSpacing.compact) {
                            Circle().fill(PrevisitDoctorAvatar(mood: mood).color).frame(width: 7, height: 7)
                            Text(mood.title).appTextStyle(.caption)
                        }.frame(maxWidth: .infinity)
                    }
                    Text("From. \(patientName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }.padding(.horizontal, 10)
            }
            VStack(spacing: AppSpacing.compact) {
                Button(completedDraft == nil ? (startTitle ?? "진료 전 기록하기") : "기록 보러가기", action: onStart)
                    .buttonStyle(AppButtonStyle())
            }
        }
    }
}
