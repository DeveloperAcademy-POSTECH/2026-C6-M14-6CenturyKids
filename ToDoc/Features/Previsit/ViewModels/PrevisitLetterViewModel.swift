//
//  PrevisitLetterViewModel.swift
//  ToDoc
//
//  Created by seokho on 10/26/26.
//

import Foundation
import Observation

/// 전송한 진료 전 기록(고른 날·하고싶은말·기분)을 보여 주고 하고싶은말을 고친다.
/// 저장 계약이 아직 없어 로그인 동안 메모리에만 둔다 (앱을 다시 켜면 사라진다)
@MainActor
@Observable
final class PrevisitLetterViewModel {
    private(set) var sent: PrevisitDraft?
    /// 보낸 때의 주치의 이름 ("To 학로쌤")
    private(set) var doctorName = "선생님"
    /// 고치는 중인 하고싶은말 (nil이면 고치는 중이 아님)
    var editingLetter: String?

    var isEditing: Bool { editingLetter != nil }

    func send(_ draft: PrevisitDraft, to doctorName: String) {
        sent = draft
        self.doctorName = doctorName
        editingLetter = nil
    }

    func beginEdit() {
        guard let sent, editingLetter == nil else { return }
        editingLetter = sent.letter
    }

    /// 고친 원문을 그대로 남긴다 (편지는 선택 입력이라 빈 글도 허용)
    func finishEdit() {
        guard let editingLetter else { return }
        sent?.letter = editingLetter
        self.editingLetter = nil
    }
}
