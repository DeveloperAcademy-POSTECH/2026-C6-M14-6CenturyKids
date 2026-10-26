import SwiftUI

/// 전송한 진료 전 기록을 보고 하고싶은말을 고칩니다. 디자인 확정 전 임시 화면입니다.
struct PrevisitLetterView: View {
    let viewModel: PrevisitLetterViewModel
    var patientName = ""
    /// 전송 직후 팝업에서 들어오면 돌아갈 곳이 없어 뒤로가기를 숨깁니다
    var showsBack = true
    var onHome: () -> Void = {}
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(title: "진료 전 기록", description: "전송한 내용을 확인하고 수정해주세요")
                .overlay(alignment: .topLeading) {
                    if showsBack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppColors.Previsit.backIcon).frame(width: 40, height: 40)
                                .background(AppColors.Previsit.backSurface, in: Circle())
                        }.accessibilityLabel("뒤로").padding(.leading, 24).padding(.top, 5)
                    }
                }
            ScrollView {
                if let sent = viewModel.sent {
                    VStack(spacing: 20) {
                        if let day = sent.day { PrevisitDayCard(day: day) }
                        letterCard(sent.letter)
                        if let mood = sent.mood {
                            HStack(spacing: 20) {
                                PrevisitDoctorAvatar(mood: mood, size: 40)
                                Text(mood.title).appFont(.body).foregroundStyle(AppColors.Previsit.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(24).appSurface(.previsitCard())
                        }
                    }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, 40).padding(.bottom, 30)
                } else {
                    Text("아직 전송한 진료 전 기록이 없어요.")
                        .appTextStyle(.caption).foregroundStyle(.secondary).padding(.top, 40)
                        .accessibilityIdentifier("previsitLetter.empty")
                }
            }.scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar).toolbar(.hidden, for: .tabBar)
        .onChange(of: writing) { _, focused in if !focused { viewModel.finishEdit() } }
        .onDisappear { viewModel.finishEdit() }
    }

    private func letterCard(_ letter: String) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("To \(viewModel.doctorName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
            if viewModel.isEditing {
                TextEditor(text: Binding { viewModel.editingLetter ?? "" } set: { viewModel.editingLetter = $0 })
                    .appFont(.body).multilineTextAlignment(.center).scrollContentBackground(.hidden)
                    .focused($writing).frame(minHeight: 156).onAppear { writing = true }
                    .accessibilityLabel("선생님께 전할 이야기").accessibilityIdentifier("previsitLetter.editor")
            } else {
                Button { viewModel.beginEdit() } label: {
                    Text(letter.isEmpty ? "하고싶은말을 자유롭게 작성해주세요." : letter)
                        .appFont(.body).multilineTextAlignment(.center)
                        .foregroundStyle(letter.isEmpty ? AppColors.Previsit.placeholder : AppColors.Previsit.title)
                        .frame(maxWidth: .infinity, minHeight: 156)
                }.buttonStyle(.plain).accessibilityHint("눌러서 수정할 수 있어요")
                    .accessibilityIdentifier("previsitLetter.letter")
            }
            Text("From. \(patientName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.vertical, 40)
            .appSurface(.previsitCard(selected: viewModel.isEditing))
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: AppSpacing.compact) {
            if writing {
                Button { writing = false } label: {
                    Text("입력 완료").appTextStyle(.label).frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered).accessibilityIdentifier("previsitLetter.finishWriting")
            } else {
                if viewModel.sent != nil {
                    Text("눌러서 수정 할 수 있어요").appTextStyle(.caption).foregroundStyle(AppColors.Previsit.moodCaption)
                }
                Button("홈으로 돌아가기", action: onHome).buttonStyle(AppButtonStyle())
                    .accessibilityIdentifier("previsitLetter.home")
            }
        }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, 12).padding(.bottom, 2)
            .background(AppColors.background)
    }
}

#if DEBUG
#Preview("하고싶은말 · 전송 후") {
    let viewModel = PrevisitLetterViewModel()
    viewModel.send(.init(day: PrevisitSectionPreview.days[1], letter: PrevisitSectionPreview.sampleLetter, mood: .comfortable), to: "학로쌤")
    return NavigationStack { PrevisitLetterView(viewModel: viewModel, patientName: "최연우") }
}
#endif
