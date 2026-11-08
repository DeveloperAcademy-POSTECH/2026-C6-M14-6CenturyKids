import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 홈의 읽기 작업과 문구 선택을 관리합니다. 알림·코멘트·기록 저장은 호출하지 않습니다.
@MainActor final class HomeViewModel {
    let state = HomeScreenState()
    private let repositories: HomeRepositories
    private let chooseGreetingIndex: (Int) -> Int
    private var context: HomeContext
    private var request: Task<Void, Never>?
    private var generation = 0

    init(patientID: UUID? = nil, repositories: HomeRepositories? = nil,
         chooseGreetingIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }) {
        self.repositories = repositories ?? .unavailable
        self.chooseGreetingIndex = chooseGreetingIndex
        context = .init(patientID: patientID, isVisible: false, isAppActive: false)
        state.doctor = patientID == nil ? .unavailable : .idle
    }

    @discardableResult
    func updateContext(_ next: HomeContext) -> Task<Void, Never>? {
        let previous = context
        guard next != previous else { return request }
        let patientChanged = next.patientID != previous.patientID
        if patientChanged {
            cancel()
            state.doctor = next.patientID == nil ? .unavailable : .idle
        }
        context = next
        let enteredHome = next.isVisible && !previous.isVisible
        if next.isVisible && next.isAppActive && (enteredHome || !previous.isAppActive || patientChanged) {
            refreshUnreadBadge()
        }
        if next.isVisible && (enteredHome || state.greeting == nil) {
            state.greeting = HomeGreeting.pick(excluding: state.greeting, chooseIndex: chooseGreetingIndex)
        }
        guard next.isVisible && next.isAppActive else {
            cancel()
            return nil
        }
        if patientChanged || enteredHome || !previous.isAppActive {
            return reload()
        }
        return request
    }

    @discardableResult
    func reload() -> Task<Void, Never>? {
        guard context.isVisible && context.isAppActive else { return nil }
        guard let patientID = context.patientID, let patients = repositories.patients else {
            state.doctor = .unavailable
            return nil
        }
        if let request { return request }
        generation += 1
        let current = generation
        let saved = state.doctor.connection
        let doctors = repositories.doctors
        state.doctor = .loading(previous: saved)

        // Repository 대기 중에는 VM을 강하게 잡지 않습니다. 닫힌 흐름의 응답은 세대로도 차단합니다.
        let work = Task { [weak self] in
            var previous = saved
            defer { self?.finishRequest(current) }
            do {
                let result = try await patients.findById(patientID)
                guard self?.accepts(current, patientID: patientID) == true else { return }
                guard let patient = result else {
                    previous = nil
                    throw HomeIssue.patientUnavailable
                }
                guard patient.user.id == patientID else {
                    previous = nil
                    throw HomeIssue.patientMismatch
                }
                self?.state.patientName = patient.user.name
                guard let doctorID = patient.doctorId else {
                    self?.state.doctor = .loaded(.unlinked)
                    return
                }
                if case .linked(let identity) = previous, identity.id == doctorID {
                    // 같은 환자/의사 관계가 확인된 기존 값만 갱신 중에도 유지합니다.
                } else {
                    previous = nil
                    self?.state.doctor = .loading(previous: nil)
                }
                guard let doctors else {
                    self?.state.doctor = .unavailable
                    return
                }
                let doctorResult = try await doctors.findById(doctorID)
                guard self?.accepts(current, patientID: patientID) == true else { return }
                guard let doctor = doctorResult else {
                    previous = nil
                    throw HomeIssue.doctorUnavailable
                }
                guard doctor.user.id == doctorID else {
                    previous = nil
                    throw HomeIssue.doctorMismatch
                }
                self?.state.doctor = .loaded(.linked(.init(id: doctor.user.id, name: doctor.user.name)))
            } catch {
                guard self?.accepts(current, patientID: patientID) == true else { return }
                if error is CancellationError {
                    self?.state.doctor = previous.map(HomeDoctorState.loaded) ?? .idle
                } else {
                    self?.state.doctor = .failed(error as? HomeIssue ?? .loadFailed, previous: previous)
                }
            }
        }
        request = work
        return work
    }

    /// 폰에 남긴 알림 중 읽지 않은 것이 있으면 종에 빨간 점을 켭니다.
    func refreshUnreadBadge() {
        guard let patientID = context.patientID, let notifications = repositories.notifications else { return }
        Task { [weak self] in
            let unread = (try? await notifications.countUnreadByUserId(patientID)) ?? 0
            guard self?.context.patientID == patientID else { return }
            self?.state.showsUnreadBadge = unread > 0
        }
    }

    func cancel() {
        generation += 1
        request?.cancel()
        request = nil
        if case .loading(let previous) = state.doctor {
            state.doctor = previous.map(HomeDoctorState.loaded) ?? (context.patientID == nil ? .unavailable : .idle)
        }
    }

    private func accepts(_ current: Int, patientID: UUID) -> Bool {
        current == generation && context.patientID == patientID
            && context.isVisible && context.isAppActive && !Task.isCancelled
    }

    private func finishRequest(_ current: Int) {
        if current == generation { request = nil }
    }
}
