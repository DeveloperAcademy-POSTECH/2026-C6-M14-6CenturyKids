import SwiftUI

/// 바탕과 테두리만 공유합니다. 내용의 여백·높이·선택 동작은 화면이 소유합니다.
struct AppSurfaceToken {
    let fill: Color
    let cornerRadius: CGFloat
    var border: Color = .clear
    var borderWidth: CGFloat = 0
}

extension View {
    func appSurface(_ token: AppSurfaceToken) -> some View {
        background(token.fill, in: RoundedRectangle(cornerRadius: token.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: token.cornerRadius)
                    .stroke(token.border, lineWidth: token.borderWidth)
                    .allowsHitTesting(false)
            }
    }
}
