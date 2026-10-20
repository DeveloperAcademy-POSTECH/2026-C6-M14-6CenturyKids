import SwiftUI

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var error: String? = nil
    var appearance: Appearance = .standard
    @State private var showsPassword = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.Auth.fieldLabelGap) {
            if appearance == .standard { Text(title).appTextStyle(.label) }
            HStack(spacing: AppSpacing.compact) {
                Group {
                    if isSecure && !showsPassword {
                        SecureField(title, text: $text, prompt: prompt)
                    } else {
                        TextField(title, text: $text, prompt: prompt)
                    }
                }
                .focused($isFocused)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(title)
                .accessibilityHint(error ?? "")
                if isSecure && appearance == .standard {
                    Button {
                        showsPassword.toggle()
                        isFocused = true
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .frame(minWidth: AppMetrics.Control.minimumHitSize, minHeight: AppMetrics.Control.minimumHitSize)
                    }
                    .accessibilityLabel(showsPassword ? "비밀번호 숨기기" : "비밀번호 보기")
                }
            }
            .appTextStyle(.label)
            .padding(.horizontal, AppSpacing.Auth.inputPadding)
            .padding(.vertical, isSecure && appearance == .standard ? AppSpacing.compact : AppSpacing.Auth.inputPadding)
            .frame(minHeight: AppMetrics.Auth.inputMinimumHeight)
            .appSurface(inputSurface)
            if let error { AuthMessage(text: error) }
        }
    }
    private var prompt: Text {
        Text(placeholder).foregroundStyle(AppColors.Text.secondary)
    }

    private var focusColor: Color { appearance == .login ? AppColors.Auth.loginFocus : AppColors.Auth.inputFocus }

    private var inputSurface: AppSurfaceToken {
        var token = AppSurfaceToken.authInput
        token.border = error != nil ? AppColors.Feedback.error : (isFocused ? focusColor : .clear)
        token.borderWidth = appearance == .login && isFocused
            ? AppMetrics.Auth.loginFocusBorderWidth : AppMetrics.Auth.inputBorderWidth
        return token
    }
}

struct AuthChoice: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.tight)
                if isSelected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .appTextStyle(.label)
            .padding(AppSpacing.Auth.inputPadding)
            .frame(maxWidth: .infinity, minHeight: AppMetrics.Auth.inputMinimumHeight)
            .appSurface(.authChoice(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
