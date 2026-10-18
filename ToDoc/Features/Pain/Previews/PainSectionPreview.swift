#if DEBUG
import SwiftUI

/// 이 섹션의 예시 상태만 선택합니다. 실제 저장·Repository·대시보드를 호출하지 않습니다.
enum PainSectionPreviewScene: String, CaseIterable, Identifiable {
    case locationHint = "01 부위 선택 · 안내"
    case locationEmpty = "02 부위 선택 · 첫 진입"
    case locationSelected = "03 가슴·등 선택"
    case beforeEmpty = "04 복용 전 · 입력 전"
    case beforeSelected = "05 복용 전 · 8점"
    case afterSelected = "06 복용 후 · 2점"
    case completion = "07 완료 · 8 → 5점"
    case zero = "08 통증 없음 · 0점"
    case same = "09 통증 변화 없음"
    case increased = "10 통증 증가"
    case saving = "11 저장 중"
    case failure = "12 저장 실패"
    case unconnected = "13 저장 미연결"

    var id: String { rawValue }

    var figmaNode: String? {
        switch self {
        case .locationHint: "1:1943"
        case .locationEmpty: "1:1951"
        case .locationSelected: "1:1957"
        case .beforeEmpty: "131:3609"
        case .beforeSelected: "131:3647"
        case .afterSelected: "131:3691"
        case .completion: "3:3862"
        default: nil
        }
    }
}

struct PainSectionPreview: View {
    @State private var scene: PainSectionPreviewScene
    @State private var input: PainFormInput
    @State private var completion: PainCompletionData?
    @State private var showsExampleRecord = false
    var showsScenePicker: Bool

    init(scene: PainSectionPreviewScene = .locationHint, showsScenePicker: Bool = true) {
        _scene = State(initialValue: scene)
        _input = State(initialValue: Self.exampleInput(for: scene))
        _completion = State(initialValue: Self.exampleCompletion(for: scene))
        self.showsScenePicker = showsScenePicker
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsScenePicker {
                Menu {
                    ForEach(PainSectionPreviewScene.allCases) { choice in
                        Button(choice.rawValue) { select(choice) }
                    }
                } label: {
                    HStack {
                        Text(scene.rawValue)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption).padding(.horizontal, 16).padding(.vertical, 10)
                }
                .accessibilityLabel("통증 Preview 상태 선택")
            }
            screen
        }
        .background(.white)
        .alert("예시 기록", isPresented: $showsExampleRecord) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text("이 Preview의 기록: \(completion?.painBefore ?? 8)점 → \(completion?.painAfter ?? 5)점")
        }
    }

    @ViewBuilder private var screen: some View {
        switch scene {
        case .locationHint, .locationEmpty, .locationSelected:
            locationScreen
        case .beforeEmpty, .beforeSelected, .zero:
            beforeScreen
        case .afterSelected, .saving, .failure, .unconnected:
            afterScreen
        case .completion, .same, .increased:
            completionScreen
        }
    }

    private var locationScreen: PainLocationSelectionView {
        PainLocationSelectionView(
            locations: input.locations,
            onToggle: { location in
                if input.locations.contains(location) {
                    input.locations.removeAll { $0 == location }
                } else {
                    input.locations.append(location)
                }
            },
            onRemove: { location in input.locations.removeAll { $0 == location } },
            onNext: { scene = .beforeEmpty },
            onClose: closeAction,
            showsSelectionHint: scene != .locationEmpty
        )
    }

    private var beforeScreen: PainBeforeMedicationView {
        PainBeforeMedicationView(
            locations: input.locations,
            score: $input.before,
            onPrevious: { scene = .locationSelected },
            onNext: { scene = .afterSelected }
        )
    }

    private var afterScreen: PainAfterMedicationView {
        PainAfterMedicationView(
            locations: input.locations,
            before: input.before ?? 0,
            score: $input.after,
            isSaving: scene == .saving,
            errorMessage: scene == .failure ? "기록을 저장하지 못했어요. 다시 시도해 주세요."
                : scene == .unconnected ? "저장 기능 연결 전이에요. 입력한 값은 저장되지 않아요." : nil,
            onPrevious: { scene = .beforeSelected },
            onSave: saveAction
        )
    }

    @ViewBuilder private var completionScreen: some View {
        if let completion {
            PainCompletionView(
                record: completion,
                onRecordAgain: { select(.locationHint) },
                onShowRecord: { showsExampleRecord = true },
                onHome: { select(.locationEmpty) }
            )
        }
    }

    private func select(_ choice: PainSectionPreviewScene) {
        input = Self.exampleInput(for: choice)
        completion = Self.exampleCompletion(for: choice)
        scene = choice
    }

    private var closeAction: (() -> Void)? {
        guard scene != .locationEmpty else { return nil }
        return { select(.locationEmpty) }
    }

    private var saveAction: (() -> Void)? {
        guard scene != .unconnected else { return nil }
        return { saveExample() }
    }

    private func saveExample() {
        guard let before = input.before, let after = input.after else { return }
        completion = .init(location: input.locations, painBefore: before,
                           painAfter: after, painChange: before - after)
        scene = .completion
    }

    private static let locations: [BodyLocation] = [
        .init(bodyPart: .chest, bodySide: .center, bodyView: .front),
        .init(bodyPart: .backLowerBack, bodySide: .center, bodyView: .back)
    ]

    private static func exampleInput(for scene: PainSectionPreviewScene) -> PainFormInput {
        switch scene {
        case .locationHint, .locationEmpty:
            PainFormInput()
        case .locationSelected, .beforeEmpty:
            PainFormInput(locations: locations)
        case .beforeSelected:
            PainFormInput(locations: locations, before: 8)
        case .zero:
            PainFormInput(locations: locations, before: 0)
        default:
            PainFormInput(locations: locations, before: 8, after: 2)
        }
    }

    private static func exampleCompletion(for scene: PainSectionPreviewScene) -> PainCompletionData? {
        let scores: (Int, Int)
        switch scene {
        case .completion: scores = (8, 5)
        case .same: scores = (5, 5)
        case .increased: scores = (2, 8)
        default: return nil
        }
        return .init(location: locations, painBefore: scores.0, painAfter: scores.1,
                     painChange: scores.0 - scores.1)
    }
}

#Preview("통증 · 전체 상태 선택") {
    PainSectionPreview()
}

#Preview("1:1943 · 부위 선택 안내") {
    PainSectionPreview(scene: .locationHint, showsScenePicker: false)
}

#Preview("1:1951 · 부위 첫 진입") {
    PainSectionPreview(scene: .locationEmpty, showsScenePicker: false)
}

#Preview("1:1957 · 부위 선택됨") {
    PainSectionPreview(scene: .locationSelected, showsScenePicker: false)
}

#Preview("131:3609 · 복용 전 입력 전") {
    PainSectionPreview(scene: .beforeEmpty, showsScenePicker: false)
}

#Preview("131:3647 · 복용 전 8점") {
    PainSectionPreview(scene: .beforeSelected, showsScenePicker: false)
}

#Preview("131:3691 · 복용 후 2점") {
    PainSectionPreview(scene: .afterSelected, showsScenePicker: false)
}

#Preview("3:3862 · 기록 완료") {
    PainSectionPreview(scene: .completion, showsScenePicker: false)
}

#Preview("통증 · 320pt 큰 글자") {
    PainSectionPreview(scene: .afterSelected, showsScenePicker: false)
        .frame(width: 320)
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
