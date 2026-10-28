import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 알림 목록을 읽고, 누른 알림을 읽음으로 바꾼 뒤 알림 종류에 맞는 화면을 엽니다.
@MainActor final class NotificationViewModel {
    let state = NotificationScreenState()
    /// 누른 알림의 종류 (진료 전 기록이면 작성 화면을 연다)
    var onOpen: ((NotificationType) -> Void)?
    private let patientId: UUID
    private let repository: any NotificationRepository
    private let now: () -> Date
    private var notifications: [AppNotification] = []
    private var loading: Task<Void, Never>?

    init(patientId: UUID, repository: any NotificationRepository, now: @escaping () -> Date = Date.init) {
        self.patientId = patientId
        self.repository = repository
        self.now = now
        state.onReload = { [weak self] in self?.reload() }
        state.onSelect = { [weak self] in self?.select($0) }
        state.onCancel = { [weak self] in self?.loading?.cancel() }
    }

    @discardableResult
    func reload() -> Task<Void, Never> {
        loading?.cancel()
        state.loadState = .loading
        let work = Task { [weak self, repository, patientId] in
            do {
                let found = try await repository.findByUserId(patientId)
                guard !Task.isCancelled, let self else { return }
                notifications = found
                state.sections = NotificationSectionData.sections(found, now: now(), calendar: .current)
                state.loadState = .loaded
            } catch {
                guard !Task.isCancelled else { return }
                self?.state.loadState = .failed
            }
        }
        loading = work
        return work
    }

    @discardableResult
    func select(_ id: UUID) -> Task<Void, Never>? {
        guard state.selectingID == nil, let notification = notifications.first(where: { $0.id == id }) else { return nil }
        state.selectingID = id
        return Task { [weak self, repository] in
            // 읽음 표시를 남기지 못해도 화면은 연다
            try? await repository.markAsRead(id)
            guard let self else { return }
            state.selectingID = nil
            reload()
            onOpen?(notification.type)
        }
    }
}
