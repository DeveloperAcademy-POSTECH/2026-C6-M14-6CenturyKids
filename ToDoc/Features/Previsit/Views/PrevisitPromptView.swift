import SwiftUI

/// 완료 표시는 전송 결과를 받은 부모가 선택합니다. 이 View는 저장/전송하지 않습니다.
struct PrevisitPromptView: View {
    var completedDraft: PrevisitDraft?
    var doctorName = "선생님"
    var patientName = ""
    var onStart: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        ZStack {
            AppColors.Previsit.dim.ignoresSafeArea()
            ScrollView {
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
                        Button(completedDraft == nil ? "진료 전 기록하기" : "닫기", action: completedDraft == nil ? onStart : onClose)
                            .buttonStyle(AppButtonStyle())
                        if completedDraft == nil {
                            Button("다음에 다시 볼게요", action: onClose).buttonStyle(AppButtonStyle(kind: .secondary))
                        }
                    }
                }.padding(24).appSurface(.previsitPrompt)
                    .padding(.horizontal, AppSpacing.screenHorizontal).padding(.vertical, 24)
            }.scrollBounceBehavior(.basedOnSize).defaultScrollAnchor(.center)
        }
    }
}
