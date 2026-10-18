import SwiftUI

struct OpenSourceLicensesView: View {
    var body: some View {
        List(OpenSourceLicense.bundled) { license in
            NavigationLink {
                OpenSourceLicenseDetailView(license: license)
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.compact) {
                    Text(license.name).appTextStyle(.label)
                        .foregroundStyle(AppColors.Text.primary)
                    Text(license.licenseName).appTextStyle(.caption)
                        .foregroundStyle(AppColors.Text.secondary)
                }
                .padding(.vertical, AppSpacing.compact)
            }
        }
        .listStyle(.plain)
        .navigationTitle("라이선스")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.Text.primary)
    }
}

struct OpenSourceLicenseDetailView: View {
    let license: OpenSourceLicense
    private let text: String?

    init(license: OpenSourceLicense, bundle: Bundle = .main) {
        self.license = license
        text = license.loadText(in: bundle)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                Text(license.licenseName).appTextStyle(.heading)
                    .accessibilityAddTraits(.isHeader)
                if let text {
                    Text(verbatim: text).appTextStyle(.caption)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("settings.licenseText")
                } else {
                    Text("라이선스 원문을 준비하고 있어요.")
                        .appTextStyle(.label)
                        .foregroundStyle(AppColors.Text.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacing.section)
        }
        .appScreenStyle()
        .navigationTitle(license.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("라이선스 목록") {
    NavigationStack { OpenSourceLicensesView() }
}

#Preview("라이선스 원문") {
    NavigationStack { OpenSourceLicenseDetailView(license: OpenSourceLicense.bundled[0]) }
}

#Preview("원문 준비 중") {
    NavigationStack {
        OpenSourceLicenseDetailView(license: .init(name: "라이선스", licenseName: "원문",
                                                   resourceName: "NotBundled", resourceDirectory: "Licenses"))
    }
}
