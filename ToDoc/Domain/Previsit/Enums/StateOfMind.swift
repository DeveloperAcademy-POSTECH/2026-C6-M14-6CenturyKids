//
//  StateOfMind.swift
//  ToDoc
//
//  Created by 앤디 on 10/30/26.
//

nonisolated public enum StateOfMind: String, CaseIterable, Sendable {
    case candid = "candid"
    case comfortable = "comfortable"
    case slowly = "slowly"
    case carefully = "carefully"
    case unsure = "unsure"
    
    public var caption: String? {
        switch self {
        case .candid: "차분히 이야기를 들을 수 있어요"
        case .comfortable: "걱정되지만 이야기를 듣고싶어요"
        case .slowly: "걱정되는 마음이 커요"
        case .carefully: "마음의 준비가 더 필요해요"
        case .unsure: nil
        }
    }
    public var title: String {
        switch self {
        case .candid: "숨김없이 이야기 해주세요"
        case .comfortable: "편하게 이야기 해주세요"
        case .slowly: "천천히 이야기 해주세요"
        case .carefully: "조심스럽게 이야기 해주세요"
        case .unsure: "아직 잘 모르겠어요"
        }
    }
}
