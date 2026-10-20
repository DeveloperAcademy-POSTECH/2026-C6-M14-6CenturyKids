import SwiftUI

@MainActor
struct NotificationSettingsView: View {
    @State private var viewModel: NotificationSettingsViewModel

    init(viewModel: NotificationSettingsViewModel? = nil) {
        _viewModel = State(
            initialValue: viewModel ?? NotificationSettingsViewModel()
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section {
                DatePicker(
                    "알림 시간",
                    selection: selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .disabled(!viewModel.hasLoaded || viewModel.isSaving)
                .accessibilityIdentifier("settings.notification.time")
            } footer: {
                Text("선택한 시간에 이 기기에서 알림을 표시하도록 설정해요.")
            }

            Section {
                if viewModel.isLoading {
                    ProgressView("불러오는 중")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.didSave {
                    Text("알림 시간을 저장했어요.")
                        .foregroundStyle(.secondary)
                }

                Button("저장") {
                    viewModel.saveTime()
                }
                .disabled(!viewModel.canSave)
                .accessibilityIdentifier("settings.notification.save")
            }
        }
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadTime()
        }
    }

    private var selectedTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: viewModel.selectedTime) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents(
                    [.hour, .minute],
                    from: date
                )
                viewModel.selectTime(components)
            }
        )
    }
}

#Preview("알림 시간 설정") {
    NavigationStack {
        NotificationSettingsView()
    }
}
