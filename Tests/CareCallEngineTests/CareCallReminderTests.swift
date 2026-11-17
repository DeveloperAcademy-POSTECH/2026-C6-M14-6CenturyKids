import Foundation
import Testing
@testable import ToDocCareCall

@MainActor
struct CareCallReminderTests {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    private func settings(_ time: String, timezone: String = "Asia/Seoul") -> NotificationSettingsDTO {
        .init(userId: UUID(), notificationTime: time, timezone: timezone, isEnabled: true)
    }

    @Test func allHoursUseTheSameTimeZoneAndMinuteForBothReservations() throws {
        let now = date("2026-11-16T14:59:59Z") // one second before midnight in Seoul
        for hour in 0..<24 {
            for minute in [0, 59] {
                let plan = try #require(CareCallReminderSchedule(settings: settings(String(format: "%02d:%02d:00", hour, minute))))
                let next = try #require(plan.nextDate(after: now))
                #expect(next.timeIntervalSince(now) == Double(hour * 3600 + minute * 60 + 1))
                #expect(plan.components.hour == hour)
                #expect(plan.components.minute == minute)
                #expect(plan.components.second == 0)
                #expect(plan.components.timeZone?.identifier == "Asia/Seoul")
            }
        }
    }

    @Test func alreadyPassedTimeMovesToTomorrowWithoutImmediateActivity() throws {
        let plan = try #require(CareCallReminderSchedule(settings: settings("16:30:00")))
        #expect(plan.nextDate(after: date("2026-11-17T07:29:59Z")) == date("2026-11-17T07:30:00Z"))
        #expect(plan.nextDate(after: date("2026-11-17T07:30:00Z")) == date("2026-11-18T07:30:00Z"))
        #expect(plan.nextDate(after: date("2026-11-17T07:30:01Z")) == date("2026-11-18T07:30:00Z"))
    }

    @Test func invalidTimesCannotSilentlyCancelAnExistingReservation() {
        for value in ["24:00:00", "-1:00:00", "12:60:00", "12:30:10", "12:30", "oops"] {
            #expect(CareCallReminderSchedule(settings: settings(value)) == nil)
        }
    }

    private final class Repository: NotificationSettingsRepository {
        var stored: NotificationSettingsDTO?
        var writes = 0
        var failSave = false
        enum Failure: Error { case disk }
        func fetch(userId: UUID) async throws -> NotificationSettingsDTO? { stored }
        func save(settings: NotificationSettingsDTO) async throws {
            if failSave { throw Failure.disk }
            stored = settings
            writes += 1
        }
    }

    @Test func savePersistsBeforeSchedulingAndFailureDoesNotLoseTheChosenTime() async {
        let repo = Repository()
        var observedTimes: [String?] = []
        var schedulingFails = true
        let next = date("2026-11-17T07:30:00Z")
        let vm = NotificationSettingsViewModel(userId: UUID(), notificationSettingsRepository: repo) {
            observedTimes.append(repo.stored?.notificationTime)
            return schedulingFails
                ? .init(warningMessage: "실시간 현황이 꺼져 있어요")
                : .init(nextLiveActivityDate: next)
        }
        await vm.loadTime()
        vm.selectTime(.init(hour: 16, minute: 30))
        await vm.saveTime()
        #expect(vm.didSave)
        #expect(vm.savedTime.hour == 16)
        #expect(vm.reminderStatus.warningMessage != nil)
        #expect(observedTimes == ["16:30:00"])
        schedulingFails = false
        await vm.refreshSchedule()
        #expect(repo.writes == 1)
        #expect(vm.reminderStatus.warningMessage == nil)
        #expect(vm.reminderStatus.nextLiveActivityDate == next)
    }

    @Test func foregroundRefreshReplenishesScheduleWithoutOverwritingAnUnsavedTime() async {
        let repo = Repository()
        repo.stored = settings("20:00:00")
        var refreshes = 0
        let vm = NotificationSettingsViewModel(userId: UUID(), notificationSettingsRepository: repo) {
            refreshes += 1
            return .init()
        }
        await vm.loadTime()
        vm.selectTime(.init(hour: 8, minute: 15))
        await vm.refreshSchedule()
        #expect(refreshes == 2)
        #expect(vm.selectedTime.hour == 8)
        #expect(vm.savedTime.hour == 20)
        #expect(repo.writes == 0)
    }

    @Test func storageFailureDoesNotScheduleAnUnpersistedTime() async {
        let repo = Repository()
        repo.failSave = true
        var calls = 0
        let vm = NotificationSettingsViewModel(userId: UUID(), notificationSettingsRepository: repo) {
            calls += 1
            return .init()
        }
        await vm.loadTime()
        await vm.saveTime()
        #expect(!vm.didSave)
        #expect(vm.errorMessage != nil)
        #expect(calls == 0)
    }
}
