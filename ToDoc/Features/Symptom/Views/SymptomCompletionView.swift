import SwiftUI

/// Figma 2113:6758 학로_체크. 저장 성공 이후 부모 흐름에서 표시합니다.
struct SymptomCompletionView: View {
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 30) {
                    ZStack(alignment: .topLeading) {
                        Image("SymptomCompleteCheck").resizable().frame(width: 136, height: 136)
                            .offset(x: 87, y: 42)
                        Image("SymptomCompleteHakro").resizable().frame(width: 202.5, height: 202.5)
                            .offset(x: 97.4, y: 12)
                    }
                    .frame(width: 354, height: 226, alignment: .topLeading)
                    .accessibilityHidden(true)
                    VStack(spacing: 16) {
                        Text("증상이 기록되었습니다.")
                            .appTypography(.title)
                            .foregroundStyle(.black)
                            .accessibilityAddTraits(.isHeader)
                        Text("말씀해 주신 내용을 바탕으로\n문진 기록을 정리했어요.")
                            .appTypography(.body)
                            .foregroundStyle(Color(white: 114 / 255))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .padding(.top, 175)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            HStack(alignment: .top, spacing: AppLayout.Phone.columnSpacing) {
                AppActions.BackButton("홈") { onHome?() }
                    .disabled(onHome == nil)
                AppActions.Button("기록 확인하기") { onShowRecord?() }
                    .disabled(onShowRecord == nil)
            }
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview { SymptomCompletionView(onShowRecord: {}, onHome: {}) }
