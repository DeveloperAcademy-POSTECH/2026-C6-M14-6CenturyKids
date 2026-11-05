import SwiftUI

extension View {
    /// 입력이 `maximum`자를 넘으면 잘라 냅니다. `shakes`이면 입력칸을 흔들고 진동으로 알립니다.
    /// 바인딩 set에서 바로 자르면 값이 그대로라 화면이 갱신되지 않아, 바뀐 뒤에 자릅니다.
    func appTextLimit(_ text: Binding<String>, maximum: Int, shakes: Bool = false) -> some View {
        modifier(AppTextLimit(text: text, maximum: maximum, shakes: shakes))
    }
}

private struct AppTextLimit: ViewModifier {
    @Binding var text: String
    let maximum: Int
    let shakes: Bool
    @State private var hits = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onChange(of: text) { _, value in
                guard value.count > maximum else { return }
                text = String(value.prefix(maximum))
                if shakes { hits += 1 }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: hits) { content, x in
                content.offset(x: reduceMotion ? 0 : x)
            } keyframes: { _ in
                KeyframeTrack {
                    for x in [8.0, -8, 6, -6, 3, 0] { LinearKeyframe(x, duration: 0.05) }
                }
            }
            .sensoryFeedback(.error, trigger: hits)
    }
}
