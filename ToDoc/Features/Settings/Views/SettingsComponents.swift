import SwiftUI

struct SettingsScreen<Content: View>: View {
    let title: String
    var cancelTitle = "이전"
    var canSave = false
    var isSaving = false
    var save: (() -> Void)?
    let cancel: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, AppSpacing.Settings.screenHorizontal).padding(.vertical, AppSpacing.tight)
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section, content: content)
                    .padding(.horizontal, AppSpacing.Settings.screenHorizontal).padding(.top, AppSpacing.content).padding(.bottom, AppSpacing.large)
            }.scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(AppColors.Settings.primary).background(AppColors.Settings.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar).buttonStyle(.plain)
    }
    @ViewBuilder private var header: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                titleLabel
                HStack { cancelButton; Spacer(); saveButton }
            }
        } else {
            HStack(spacing: 0) {
                cancelButton.frame(width: AppMetrics.Settings.headerActionWidth, alignment: .leading)
                titleLabel.frame(maxWidth: .infinity)
                saveButton.frame(width: AppMetrics.Settings.headerActionWidth, alignment: .trailing)
            }
        }
    }
    private var titleLabel: some View {
        Text(title).appFont(.settingsNavigation).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
    }
    private var cancelButton: some View {
        Button(action: cancel) {
            HStack(spacing: 6) {
                if cancelTitle == "이전" { Image("SettingsBack").resizable().frame(width: 10.4, height: 18.4).accessibilityHidden(true) }
                Text(cancelTitle).appFont(.settingsRow)
            }.frame(minWidth: AppMetrics.Control.minimumHitSize, minHeight: AppMetrics.Control.minimumHitSize)
        }.accessibilityIdentifier("settings.cancel")
    }
    @ViewBuilder private var saveButton: some View {
        if let save {
            Button(action: save) {
                Group { if isSaving { ProgressView().accessibilityLabel("저장 중") }
                    else { Text("완료").appFont(.settingsNavigation) } }
                    .frame(minWidth: AppMetrics.Control.minimumHitSize, minHeight: AppMetrics.Control.minimumHitSize)
            }.foregroundStyle(canSave ? AppColors.Settings.action : AppColors.Settings.secondary)
                .disabled(!canSave).accessibilityIdentifier("settings.done")
        } else { Color.clear.frame(width: AppMetrics.Control.minimumHitSize, height: AppMetrics.Control.minimumHitSize).accessibilityHidden(true) }
    }

}
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            if !title.isEmpty { Text(title).appFont(.settingsSectionCaption).foregroundStyle(AppColors.Settings.caption).padding(.horizontal, AppSpacing.content) }
            VStack(spacing: 0, content: content).appSurface(.settingsGroup)
            if let footer { Text(footer).appFont(.settingsSectionCaption).foregroundStyle(AppColors.Settings.caption).padding(.horizontal, AppSpacing.content) }
        }
    }
}
struct SettingsInputRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: AppSpacing.Settings.inputGap))
        layout {
            Text(title).appFont(.settingsRow).fixedSize()
            content().frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
        }.padding(.horizontal, AppSpacing.content).padding(.vertical, AppSpacing.item).frame(minHeight: AppMetrics.Settings.inputMinimumHeight)
    }
}
struct SettingsDivider: View {
    var body: some View { Rectangle().fill(AppColors.Settings.separator).frame(height: AppMetrics.Settings.separatorHeight).padding(.leading, AppSpacing.content) }
}
struct SettingsRow: View {
    let title: String
    var value: String?
    var subtitle: String?
    var chevron = false
    var selected = false
    var connected = false
    var minimumHeight: CGFloat = AppMetrics.Settings.rowMinimumHeight
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(spacing: AppSpacing.item) {
            if typeSize.isAccessibilitySize, let value {
                VStack(alignment: .leading, spacing: 6) {
                    titleLabel
                    HStack(spacing: AppSpacing.compact) {
                        if connected { connectionDot }
                        Text(value).appFont(.settingsRow).foregroundStyle(AppColors.Settings.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            } else {
                titleLabel
                Spacer(minLength: 0)
                if connected { connectionDot }
                if let value { Text(value).appFont(.settingsRow).foregroundStyle(AppColors.Settings.secondary)
                        .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true) }
            }
            if selected { Image("SettingsCheck").resizable().frame(width: 13.2, height: 11.2).accessibilityHidden(true) }
            if chevron { Image("SettingsChevron").resizable().frame(width: 6.8, height: 11.8).accessibilityHidden(true) }
        }.padding(.horizontal, AppSpacing.content).padding(.vertical, AppSpacing.item).frame(minHeight: minimumHeight)
            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }
    private var titleLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).appFont(.settingsRow).fixedSize(horizontal: false, vertical: true)
            if let subtitle { Text(subtitle).appFont(.settingsDetail).foregroundStyle(AppColors.Settings.secondary) }
        }
    }
    private var connectionDot: some View { Circle().fill(AppColors.primary).frame(width: 7, height: 7).accessibilityHidden(true) }
}

struct SettingsFeedback: View {
    var busy = false
    var error: String?
    var success: String?
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.item) {
            if busy { ProgressView("처리 중").appFont(.settingsCaption) }
            if let error { Text(error).appFont(.settingsCaption).foregroundStyle(AppColors.Feedback.error).accessibilityIdentifier("settings.error") }
            if let success { Text(success).appFont(.settingsCaption).foregroundStyle(AppColors.Settings.action).accessibilityIdentifier("settings.success") }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
