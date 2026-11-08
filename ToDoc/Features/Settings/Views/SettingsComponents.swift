import SwiftUI

/// 설정 하이파이의 그룹형 행 스타일. 공통 디자인 시스템 파일은 변경하지 않습니다.
enum SettingsPalette {
    static let background = Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    static let primary = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let secondary = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let caption = Color(red: 109 / 255, green: 109 / 255, blue: 114 / 255)
    static let action = Color.blue
}
private struct SettingsTextStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let bold: Bool
    init(size: CGFloat, bold: Bool) { _size = ScaledMetric(wrappedValue: size); self.bold = bold }
    func body(content: Content) -> some View {
        content.font(Font((bold ? AppTypography.Style.heading : .caption).font(at: size)))
    }
}
extension View {
    func settingsText(_ size: CGFloat = 17, bold: Bool = false) -> some View {
        modifier(SettingsTextStyle(size: size, bold: bold))
    }
}

struct SettingsScreen<Content: View>: View {
    let title: String
    var cancelTitle = "이전"
    var canSave = false
    var isSaving = false
    var fillsAvailableHeight = false
    var save: (() -> Void)?
    let cancel: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28, content: content)
                    .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 32)
                    .frame(minHeight: fillsAvailableHeight ? geometry.size.height : 0, alignment: .top)
                    .buttonStyle(.plain)
            }.scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(SettingsPalette.primary).background(SettingsPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden().navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title).settingsText(20, bold: true).accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(action: cancel) {
                    if cancelTitle == "이전" { Image(systemName: "chevron.backward") }
                    else { Text(cancelTitle) }
                }.tint(SettingsPalette.primary).disabled(isSaving).accessibilityLabel(cancelTitle).accessibilityIdentifier("settings.cancel")
            }
            ToolbarItem(placement: .confirmationAction) { saveButton }
        }
        .tint(SettingsPalette.action)
    }
    @ViewBuilder private var saveButton: some View {
        if let save {
            Button(action: save) {
                Group { if isSaving { ProgressView().accessibilityLabel("저장 중") }
                    else { Image(systemName: "checkmark").accessibilityLabel("완료") } }
                    .frame(minWidth: 44, minHeight: 44)
            }.foregroundStyle(canSave ? SettingsPalette.action : SettingsPalette.secondary)
                .disabled(!canSave).accessibilityIdentifier("settings.done")
        }
    }

}
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty { Text(title).settingsText(16, bold: true).foregroundStyle(SettingsPalette.caption) }
            VStack(spacing: 0, content: content).background(.white, in: RoundedRectangle(cornerRadius: 26))
            if let footer { Text(footer).settingsText(13).foregroundStyle(SettingsPalette.caption).padding(.horizontal, 16) }
        }
    }
}
struct SettingsInputRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 20))
        layout {
            Text(title).settingsText().fixedSize()
            content().frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
        }.padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 54)
    }
}
struct SettingsDivider: View {
    var body: some View { Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.64).padding(.leading, 16) }
}
struct SettingsRow: View {
    let title: String
    var value: String?
    var subtitle: String?
    var chevron = false
    var selected = false
    var connected = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(spacing: 12) {
            if typeSize.isAccessibilitySize, let value {
                VStack(alignment: .leading, spacing: 6) {
                    titleLabel
                    HStack(spacing: 8) {
                        if connected { connectionDot }
                        Text(value).settingsText().foregroundStyle(SettingsPalette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            } else {
                titleLabel
                Spacer(minLength: 0)
                if connected { connectionDot }
                if let value { Text(value).settingsText().foregroundStyle(SettingsPalette.secondary)
                        .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true) }
            }
            if selected { Image("SettingsCheck").resizable().frame(width: 13.2, height: 11.2).accessibilityHidden(true) }
            if chevron { Image("SettingsChevron").resizable().frame(width: 6.8, height: 11.8).accessibilityHidden(true) }
        }.padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
    private var titleLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).settingsText().fixedSize(horizontal: false, vertical: true)
            if let subtitle { Text(subtitle).settingsText(13).foregroundStyle(SettingsPalette.secondary) }
        }
    }
    private var connectionDot: some View { Circle().fill(AppColors.primary).frame(width: 7, height: 7).accessibilityHidden(true) }
}

struct SettingsFeedback: View {
    var busy = false
    var error: String?
    var success: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if busy { ProgressView("처리 중").settingsText(14) }
            if let error { Text(error).settingsText(14).foregroundStyle(.red).accessibilityIdentifier("settings.error") }
            if let success { Text(success).settingsText(14).foregroundStyle(SettingsPalette.action).accessibilityIdentifier("settings.success") }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
