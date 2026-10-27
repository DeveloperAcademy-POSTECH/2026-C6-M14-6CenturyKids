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

                VStack(spacing: 32) {
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
                        TextButton(subAction.title, action: subAction.perform)
                            .disabled(!subAction.isEnabled)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        }
    }
}
