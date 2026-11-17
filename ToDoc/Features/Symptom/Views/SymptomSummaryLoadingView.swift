import SwiftUI

/// Figma 1:1816. 마지막 답변 처리 중에만 표시합니다.
struct SymptomSummaryLoadingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false

    private var usesLargeLayout: Bool { dynamicTypeSize >= .xxxLarge }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: usesLargeLayout ? 24 : 60) {
                    Image("CareSummaryLoading").resizable()
                        .frame(width: usesLargeLayout ? 72 : 100, height: usesLargeLayout ? 72 : 100)
                        .rotationEffect(.degrees(rotating && !reduceMotion ? 360 : 0))
                        .accessibilityHidden(true)
                    VStack(spacing: 24) {
                        Text("말씀해 주신 내용을 바탕으로\n문진 기록을 정리하고 있어요.")
                            .modifier(SymptomTextStyle(size: 20, weight: .medium))
                        Text("잠시만 기다려 주세요")
                            .modifier(SymptomTextStyle(size: 16))
                            .foregroundStyle(Color(white: 114 / 255))
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, usesLargeLayout ? 24 : max(24, geometry.size.height * 0.27))
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { rotating = true }
        }
    }
}

#Preview { SymptomSummaryLoadingView() }
