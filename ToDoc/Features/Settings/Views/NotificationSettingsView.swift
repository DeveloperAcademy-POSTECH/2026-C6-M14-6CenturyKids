import SwiftUI

@MainActor
struct NotificationSettingsView: View {
    @State private var viewModel: NotificationSettingsViewModel
    @State private var isPickingTime = false

    init(viewModel: NotificationSettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section {
                LabeledContent("알림 시간") {
                    Button {
                        isPickingTime = true
                    } label: {
                        Text(timeText)
                            .foregroundStyle(isPickingTime ? Color.accentColor : Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isPickingTime) {
                        HStack(spacing: 0) {
                            Picker("시", selection: hour) {
                                ForEach(allowedHours, id: \.self) { hour in
                                    Text(hourText(hour) + "시").tag(hour)
                                }
                            }
                            Picker("분", selection: minute) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text(String(format: "%02d분", minute)).tag(minute)
                                }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 280, height: 200)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                .disabled(!viewModel.hasLoaded || viewModel.isSaving)
                .accessibilityIdentifier("settings.notification.time")
            } footer: {
                Text(OfflineMode.isOn
                     ? "하루 중 어느 시각이든 고를 수 있어요. 같은 시각에 증상 기록 알림과 실시간 현황이 함께 나와요."
                     : "선택한 시간에 이 기기에서 알림을 표시하도록 설정해요.")
            }

            Section {
                if viewModel.isLoading {
                    ProgressView("불러오는 중")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)

                    if !viewModel.hasLoaded && !viewModel.isLoading {
                        Button("다시 불러오기") {
                            Task {
                                await viewModel.loadTime()
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                }

                if viewModel.didSave {
                    Text("알림 시간을 저장했어요.")
                        .foregroundStyle(.secondary)
                }

                if viewModel.isScheduling {
                    ProgressView("알림과 실시간 현황을 예약하고 있어요")
                }

                if let date = viewModel.reminderStatus.nextLiveActivityDate {
                    LabeledContent("다음 증상 실시간 현황") {
                        Text(date, format: .dateTime.month().day().hour().minute())
                    }
                    .accessibilityIdentifier("settings.notification.nextActivity")
                }

                if let warning = viewModel.reminderStatus.warningMessage {
                    Text(warning)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("settings.notification.scheduleWarning")
                    Button("예약 다시 시도") { Task { await viewModel.refreshSchedule() } }
                        .disabled(viewModel.isSaving || viewModel.isScheduling)
                    Button("iPhone 설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Button("저장") {
                    Task {
                        await viewModel.saveTime()
                    }
                }
                .disabled(!viewModel.canSave)
                .accessibilityIdentifier("settings.notification.save")
            } footer: {
                if OfflineMode.isOn {
                    Text("일반 알림은 매일 반복돼요. 실시간 현황은 다음 한 번을 예약하며, 앱을 열면 다음 일정이 이어서 예약돼요. 예약한 시각에는 인터넷 없이도 표시돼요.")
                }
            }
        }
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTime()
        }
    }

    // DatePicker는 범위 밖 시간을 숨기지 못하고 흐리게만 보여 줘서, 허용된 시만 담은 휠을 직접 그린다.
    private var allowedHours: Range<Int> {
        let minutes = viewModel.allowedMinutes
        return (minutes.lowerBound / 60)..<(minutes.upperBound / 60)
    }

    private var timeText: String {
        let hour = viewModel.selectedTime.hour ?? 20
        let minute = viewModel.selectedTime.minute ?? 0
        return hourText(hour) + ":" + String(format: "%02d", minute)
    }

    /// 20 → "오후 8", 0 → "오전 12"
    private func hourText(_ hour: Int) -> String {
        "\(hour < 12 ? "오전" : "오후") \(hour % 12 == 0 ? 12 : hour % 12)"
    }

    private var hour: Binding<Int> {
        Binding(
            get: { viewModel.selectedTime.hour ?? 20 },
            set: { hour in
                viewModel.selectTime(DateComponents(hour: hour, minute: viewModel.selectedTime.minute ?? 0))
            }
        )
    }

    private var minute: Binding<Int> {
        Binding(
            get: { viewModel.selectedTime.minute ?? 0 },
            set: { minute in
                viewModel.selectTime(DateComponents(hour: viewModel.selectedTime.hour ?? 20, minute: minute))
            }
        )
    }
}

#if DEBUG
@MainActor
private final class PreviewNotificationSettingsRepository: NotificationSettingsRepository {
    private var settings: NotificationSettingsDTO?

    func fetch(userId: UUID) async throws -> NotificationSettingsDTO? {
        guard let settings, settings.userId == userId else {
            return nil
        }

        return settings
    }

    func save(settings: NotificationSettingsDTO) async throws {
        self.settings = settings
    }
}

extension NotificationSettingsViewModel {
    @MainActor
    static func preview() -> NotificationSettingsViewModel {
        NotificationSettingsViewModel(
            userId: UUID(),
            notificationSettingsRepository: PreviewNotificationSettingsRepository()
        )
    }
}

#Preview("알림 시간 설정") {
    NavigationStack {
        NotificationSettingsView(viewModel: NotificationSettingsViewModel.preview())
    }
}
#endif
