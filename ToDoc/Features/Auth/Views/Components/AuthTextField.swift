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
        VStack(alignment: .leading, spacing: 10) {
            if appearance == .standard { Text(title).appTextStyle(.label) }
            HStack(spacing: 8) {
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
                if isSecure && appearance == .standard {
                    Button {
                        showsPassword.toggle()
                        isFocused = true
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(showsPassword ? "비밀번호 숨기기" : "비밀번호 보기")
                }
            }
            .appTextStyle(.label)
            .padding(.horizontal, 18)
            .padding(.vertical, isSecure && appearance == .standard ? 8 : 18)
            .frame(minHeight: 60)
            .background(AppColors.secondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(error != nil ? Color.red : (isFocused ? focusColor : .clear),
                            lineWidth: appearance == .login && isFocused ? 3 : 1)
                    .allowsHitTesting(false)
            }
            if let error { AuthMessage(text: error) }
        }
    }
    private var prompt: Text {
        Text(placeholder).foregroundStyle(AppColors.Text.secondary)
    }

    private var focusColor: Color { appearance == .login ? .blue : AppColors.gray }
}

struct AuthChoice: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if isSelected { Image(systemName: "checkmark") }
            }
            .appTextStyle(.label)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isSelected ? AppColors.primary : AppColors.secondary,
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
