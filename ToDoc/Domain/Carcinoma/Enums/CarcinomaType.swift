import Foundation

/// 기존 선택지와 직접 입력한 이름을 같은 carcinoma_type 문자열로 저장합니다.
nonisolated public struct CarcinomaType: RawRepresentable, CaseIterable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty,
              rawValue == rawValue.trimmingCharacters(in: .whitespacesAndNewlines),
              rawValue.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        self.rawValue = rawValue
    }

    /// 입력 앞뒤 공백을 제거하고, 기존 표시 이름이면 기존 저장 값을 사용합니다.
    public init?(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Self(rawValue: name) else { return nil }
        self = Self.allCases.first { $0.displayName == name } ?? value
    }

    private init(preset: String) { rawValue = preset }

    public static let liver = Self(preset: "liver")
    public static let thyroid = Self(preset: "thyroid")
    public static let gallbladderAndBileDuct = Self(preset: "gallbladderAndBileDuct")
    public static let colorectal = Self(preset: "colorectal")
    public static let kidney = Self(preset: "kidney")
    public static let stomach = Self(preset: "stomach")
    public static let breast = Self(preset: "breast")
    public static let prostate = Self(preset: "prostate")
    public static let pancreas = Self(preset: "pancreas")
    public static let lung = Self(preset: "lung")
    public static let larynx = Self(preset: "larynx")
    public static let thymus = Self(preset: "thymus")
    public static let esophagus = Self(preset: "esophagus")
    public static let smallIntestine = Self(preset: "smallIntestine")
    public static let anus = Self(preset: "anus")
    public static let unknown = Self(preset: "unknown")

    /// 선택 목록에는 기존 암종 15개와 모름만 표시합니다.
    public static let allCases: [Self] = [
        .liver, .thyroid, .gallbladderAndBileDuct, .colorectal, .kidney, .stomach,
        .breast, .prostate, .pancreas, .lung, .larynx, .thymus, .esophagus,
        .smallIntestine, .anus, .unknown
    ]

    public var displayName: String {
        switch self {
        case .liver: "간암"
        case .thyroid: "갑상선암"
        case .gallbladderAndBileDuct: "담낭 및 담도암"
        case .colorectal: "대장암"
        case .kidney: "신장암"
        case .stomach: "위암"
        case .breast: "유방암"
        case .prostate: "전립선암"
        case .pancreas: "췌장암"
        case .lung: "폐암"
        case .larynx: "후두암"
        case .thymus: "흉선암"
        case .esophagus: "식도암"
        case .smallIntestine: "소장암"
        case .anus: "항문암"
        case .unknown: "잘 모르겠어요"
        default: rawValue
        }
    }
}
