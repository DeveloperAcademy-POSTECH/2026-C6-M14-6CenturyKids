import SwiftUI

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    /// false여도 라벨 공간을 유지해 입력칸 위치가 바뀌지 않습니다.
    var showsLabel = true
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var error: String? = nil
    var appearance: Appearance = .standard
    var focus: FocusState<Bool>.Binding? = nil
    @Environment(\.authInputDismissal) private var inputDismissal
    @State private var showsPassword = false
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .body) private var labelSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var placeholderSize: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appearance == .standard {
                Text(title).tracking(labelSize * 0.015).appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .opacity(showsLabel ? 1 : 0)
                    .accessibilityHidden(!showsLabel)
            }
            HStack(spacing: 8) {
                Group {
                    if isSecure && !showsPassword {
                        SecureField(title, text: $text, prompt: prompt)
                    } else {
                        TextField(title, text: $text, prompt: prompt)
                    }
                }
                .focused(fieldFocus)
                .onChange(of: inputDismissal) { fieldFocus.wrappedValue = false }
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(title)
                .accessibilityHint(error ?? "")
                .tracking(labelSize * 0.015)
                .appTypography(.labelLarge)
                .foregroundStyle(AppColors.Semantic.Text.default)
                if isSecure && appearance == .standard {
                    Button {
                        showsPassword.toggle()
                        fieldFocus.wrappedValue = true
                    } label: {
                        Image(systemName: showsPassword ? "eye" : "eye.slash")
                            .foregroundStyle(AppColors.Semantic.Text.disabled)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(AppActions.PressStyle())
                    .accessibilityLabel(showsPassword ? "비밀번호 숨기기" : "비밀번호 보기")
                }
            }
            .padding(.horizontal, appearance == .login ? 24 : 16)
            .padding(.vertical, isSecure && appearance == .standard ? 10 : 16)
            .frame(minHeight: 64)
            .background(appearance == .login ? AppColors.Semantic.Background.default : AppColors.Surface.control,
                        in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
                    .allowsHitTesting(false)
            }
            if let error { AuthMessage(text: error) }
        }
    }
    private var prompt: Text {
        Text(placeholder)
            .font(Font(AppTypography.font(for: .captionRegular, size: placeholderSize)))
            .tracking(placeholderSize * -0.01)
            .foregroundStyle(appearance == .login ? AppColors.Semantic.Text.placeholder : AppColors.Semantic.Text.disabled)
    }

    private var focusColor: Color { appearance == .login ? AppColors.Auth.loginFocus : AppColors.Auth.inputFocus }

    private var fieldFocus: FocusState<Bool>.Binding { focus ?? $isFocused }

    private var borderColor: Color {
        error != nil ? AppColors.Semantic.Border.error : (fieldFocus.wrappedValue ? focusColor : .clear)
    }

    private var borderWidth: CGFloat {
        appearance == .login && fieldFocus.wrappedValue ? AppMetrics.Auth.loginFocusBorderWidth : 1.5
    }
}

private struct AuthInputDismissalKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var authInputDismissal: Int {
        get { self[AuthInputDismissalKey.self] }
        set { self[AuthInputDismissalKey.self] = newValue }
    }
}

struct AuthChoice: View {
    enum Kind { case list, centered }

    let title: String
    let isSelected: Bool
    var kind: Kind = .list
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var labelSize: CGFloat = 16

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppLayout.Phone.columnSpacing) {
                if kind == .list {
                    selectionMark.accessibilityHidden(true)
                }
                Text(title).tracking(labelSize * 0.015).appTypography(.labelLarge)
                    .foregroundStyle(kind == .centered ? AppColors.Semantic.Text.sub : AppColors.Semantic.Text.default)
                    .multilineTextAlignment(kind == .centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: kind == .centered ? .center : .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: kind == .centered ? 64 : 56)
            .background(isSelected ? AppColors.Semantic.Background.selected
                        : AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? AppColors.Semantic.Primary.default
                                  : AppColors.Semantic.Border.default, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(AppActions.PressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectionMark: some View {
        ZStack {
            if isSelected {
                Image("Auth/ChoiceSelected")
                    .resizable()
                    .frame(width: 16, height: 16)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.Semantic.Text.action)
            } else {
                Image("Auth/ChoiceOff")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
        .frame(width: 24, height: 24)
    }
}
