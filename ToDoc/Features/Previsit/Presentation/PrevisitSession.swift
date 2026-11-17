import Foundation
import Observation

/// Saves each draft edit on-device so a force quit does not lose the letter.
@Observable final class PrevisitSession {
    var draft: PrevisitDraft { didSet { persist() } }
    private(set) var step: PrevisitStep { didSet { persist() } }
    private(set) var isWriting = false
    private(set) var persistenceError: String?
    @ObservationIgnored private let storageURL: URL?
    private struct Saved: Codable { let draft: PrevisitDraft; let step: PrevisitStep }
    static let deviceDraftURL = URL.applicationSupportDirectory.appending(path: "OfflineBooth/previsit-draft.json")
    static let didResetDraft = Notification.Name("offlineBoothDidResetPrevisitDraft")

    static func removeDeviceDraft() throws {
        if FileManager.default.fileExists(atPath: deviceDraftURL.path) {
            try FileManager.default.removeItem(at: deviceDraftURL)
        }
        NotificationCenter.default.post(name: didResetDraft, object: nil)
    }
    @ObservationIgnored var analytics: PrevisitAnalytics

    init(step: PrevisitStep = .day, draft: PrevisitDraft = .init(), storageURL: URL? = nil,
         trackAnalytics: PrevisitAnalytics.Track? = nil) {
        self.storageURL = storageURL
        self.step = step
        self.draft = draft
        analytics = PrevisitAnalytics(track: trackAnalytics)
        if let storageURL, FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: storageURL))
                self.draft = saved.draft
                self.step = saved.step
            } catch { persistenceError = "작성 중이던 내용을 불러오지 못했어요. 저장된 진료 전 기록은 지난 기록에서 확인할 수 있어요." }
        }
    }

    private func persist() {
        guard let storageURL else { return }
        do {
            var folder = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let data = try JSONEncoder().encode(Saved(draft: draft, step: step))
            #if os(iOS)
            try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: storageURL, options: .atomic)
            #endif
            persistenceError = nil
        } catch { persistenceError = "초안을 저장하지 못했어요. 저장 공간을 확인하고 앱을 닫기 전에 기록을 저장해 주세요." }
    }

    var hasDraft: Bool {
        draft.day != nil || !draft.letter.isEmpty || draft.mood != nil
    }

    var canContinue: Bool {
        switch step {
        case .day: draft.day?.isSelectable == true
        case .letter: true // 기존 #137의 편지는 선택 입력입니다.
        case .mood: draft.mood != nil
        }
    }

    func start() { isWriting = true }
    func pause() {
        isWriting = false
        if !hasDraft { analytics.resetAttempt() }
    }

    func selectDay(_ day: PrevisitDay) {
        guard day.isSelectable else { return }
        draft.day = day
    }

    func refreshDays(_ days: [PrevisitDay]) {
        guard let selected = draft.day else { return }
        draft.day = days.first { $0.id == selected.id && $0.isSelectable }
        if draft.day == nil { step = .day }
    }

    func next() {
        guard canContinue else { return }
        switch step {
        case .day: step = .letter
        case .letter: step = .mood
        case .mood: break // 전송은 부모 흐름에서 처리합니다.
        }
    }

    func previous() {
        switch step {
        case .day: pause()
        case .letter: step = .day
        case .mood: step = .letter
        }
    }

    func discard() {
        draft = .init()
        step = .day
        pause()
    }
}
