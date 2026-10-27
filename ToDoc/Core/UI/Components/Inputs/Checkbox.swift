import SwiftUI

extension AppInputs {
    /// Figma Checkbox. 표시는 24pt, 터치 영역은 44pt이며 제목은 VoiceOver에 전달합니다.
    struct Checkbox: View {
        private let title: String
        @Binding private var isOn: Bool

        init(_ title: String, isOn: Binding<Bool>) {
            self.title = title
            self._isOn = isOn
        }

        var body: some View {
            SwiftUI.Toggle(title, isOn: $isOn)
                .toggleStyle(CheckboxStyle())
        }
    }

    private struct CheckboxStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            SwiftUI.Button {
                configuration.isOn.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isOn ? AppColors.Semantic.Primary.default
                          : AppColors.Semantic.Background.surface)
                    .overlay {
                        if configuration.isOn {
                            Image("DesignSystem/Components/Inputs/CheckboxCheck")
                                .renderingMode(.template)
                                .resizable()
                                .foregroundStyle(AppColors.Semantic.Text.onPrimary)
                                .frame(width: 14, height: 11)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(AppColors.Semantic.Border.default, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .accessibilityRepresentation {
                SwiftUI.Toggle(isOn: configuration.$isOn) {
                    configuration.label
                }
                .toggleStyle(.switch)
            }
        }
    }
}
