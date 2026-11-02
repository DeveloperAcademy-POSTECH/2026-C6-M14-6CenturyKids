import SwiftUI

extension AppActions {
    /// Figma의 Bottom Action. 화면에서는 safeAreaInset(edge: .bottom)에 배치합니다.
    /// Home Bar는 iOS가 그리므로 이 컴포넌트에 포함하지 않습니다.
    struct BottomAction: View {
        let primary: Action
        var caption: String? = nil
        var backAction: (() -> Void)? = nil
        var secondary: Action? = nil
        var subAction: Action? = nil

        var body: some View {
            VStack(spacing: 24) {
                if let caption {
                    Text(caption)
                        // Figma의 Caption Text 레이어에 지정된 실제 스타일은 body/small입니다.
                        .appTypography(.bodySmall)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Figma Bottom Action(1455:21551): 버튼과 보조 액션 글자 사이 24
                VStack(spacing: 24) {
                    VStack(spacing: 20) {
                        HStack(alignment: .top, spacing: AppLayout.Phone.columnSpacing) {
                            if let backAction {
                                BackButton(action: backAction)
                            }
                            Button(primary.title, action: primary.perform)
                                .disabled(!primary.isEnabled)
                        }

                        if let secondary {
                            Button(secondary.title, kind: .secondary, action: secondary.perform)
                                .disabled(!secondary.isEnabled)
                        }
                    }

                    if let subAction {
                        // 글자 칸은 Figma처럼 19로 홈 표시줄 바로 위에 두고, 누르는 영역 44는 위아래로 겹쳐 유지합니다
                        TextButton(subAction.title, action: subAction.perform)
                            .disabled(!subAction.isEnabled)
                            .padding(.vertical, -12.5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        }
    }
}
