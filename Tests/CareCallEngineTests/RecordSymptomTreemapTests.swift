import CoreGraphics
import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

struct RecordSymptomTreemapTests {
    /// Pretendard 한 글자 폭을 글자 크기의 0.93배로 어림합니다 (개발 전달 7번 필요 폭: 28 Bold '식욕부진' 104)
    let measure: RecordSymptomTreemap.Measure = { text, size, _ in CGFloat(text.count) * size * 0.93 }
    func labels(_ names: [String], _ counts: [Int]) -> [RecordSymptomTreemap.Label] {
        zip(names, counts).map { RecordSymptomTreemap.Label(name: $0, count: "\($1)회") }
    }

    /// Figma 06 Patterns "하루 기록 · 최종 (증상 1~8개)"의 칸 (x, y, 폭, 높이)과 글자 단계
    static let figma: [(names: [String], counts: [Int], rects: [[Int]], tiers: [RecordSymptomTreemap.Tier])] = [
        (["메스꺼움"], [2], [[0, 0, 354, 240]], [.a]),
        (["메스꺼움", "설사"], [3, 1], [[0, 0, 266, 240], [266, 0, 89, 240]], [.a, .a]),
        (["메스꺼움", "설사", "피부발진"], [4, 2, 1],
         [[0, 0, 202, 240], [202, 0, 152, 160], [202, 160, 152, 80]], [.a, .a, .a]),
        (["메스꺼움", "설사", "피부발진", "변비"], [4, 3, 2, 1],
         [[0, 0, 142, 240], [142, 0, 212, 120], [142, 120, 142, 120], [283, 120, 71, 120]], [.a, .a, .a, .a]),
        (["메스꺼움", "설사", "식욕부진", "피부발진", "변비"], [5, 3, 2, 2, 1],
         [[0, 0, 136, 240], [136, 0, 131, 150], [267, 0, 87, 150], [136, 150, 145, 90], [281, 150, 73, 90]],
         [.a, .a, .c, .a, .c]),
        // 6개만 (나) 최소 칸 보장 배치가 뽑힙니다
        (["메스꺼움", "설사", "식욕부진", "피부발진", "손발저림", "변비"], [5, 3, 3, 2, 2, 1],
         [[0, 0, 174, 150], [0, 150, 174, 90], [174, 0, 108, 145], [282, 0, 72, 145], [174, 145, 110, 95], [285, 145, 69, 95]],
         [.a, .a, .b, .d, .b, .d]),
        (["메스꺼움", "설사", "식욕부진", "피부발진", "손발저림", "변비", "구내염"], [5, 3, 3, 2, 2, 1, 1],
         [[0, 0, 167, 150], [0, 150, 167, 90], [167, 0, 112, 133], [279, 0, 75, 133], [167, 133, 94, 107],
          [260, 133, 94, 53], [260, 187, 94, 53]],
         [.a, .a, .b, .d, .c, .d, .d]),
        // 변비는 혼자면 24도 들어가지만 더 큰 손발저림(16)보다 큰 글씨를 쓸 수 없어 16
        (["메스꺼움", "설사", "식욕부진", "피부발진", "손발저림", "변비", "구내염", "기타"], [5, 3, 3, 2, 2, 1, 1, 1],
         [[0, 0, 157, 150], [0, 150, 157, 90], [157, 0, 118, 120], [275, 0, 79, 120], [157, 120, 79, 120],
          [236, 120, 59, 80], [295, 120, 59, 80], [236, 200, 118, 40]],
         [.a, .a, .a, .d, .d, .d, .d, .e]),
    ]

    @Test(arguments: 0..<8) func Figma_시안과_같은_칸과_글자_단계가_된다(screen: Int) {
        let (names, counts, rects, tiers) = Self.figma[screen]
        let cells = RecordSymptomTreemap.layout(weights: counts.map(Double.init), labels: labels(names, counts),
                                                in: CGSize(width: 354, height: 240), measure: measure)
        let actual = cells.map { [$0.rect.minX, $0.rect.minY, $0.rect.width, $0.rect.height].map { Int($0.rounded()) } }
        // Figma는 정수로 반올림해 둔 값이라 1pt까지 봐줍니다
        #expect(zip(actual, rects).allSatisfy { zip($0, $1).allSatisfy { abs($0 - $1) <= 1 } }, "\(screen + 1)개: \(actual)")
        #expect(cells.map(\.tier) == tiers, "\(screen + 1)개")
    }

    @Test func 칸은_넓이가_횟수에_비례하고_영역을_빈틈없이_채운다() {
        for counts in [[2], [3, 1], [4, 1, 1], [4, 2, 1, 1], [5, 3, 2, 1, 1], [5, 3, 2, 2, 1, 1]] {
            let size = CGSize(width: 354, height: 240)
            let rects = RecordSymptomTreemap.squarify(counts.map(Double.init), in: CGRect(origin: .zero, size: size))
            let total = Double(counts.reduce(0, +))
            for (rect, count) in zip(rects, counts) {
                #expect(abs(Double(rect.width * rect.height) - Double(size.width * size.height) * Double(count) / total) < 0.5)
            }
            #expect(rects.allSatisfy { CGRect(origin: .zero, size: size).insetBy(dx: -0.01, dy: -0.01).contains($0) })
        }
    }

    @Test func 일은_횟수_없이_이름만_잰다() {
        let label = RecordSymptomTreemap.Label(name: "설사", count: nil)
        // 횟수 줄이 없어 28 Bold 이름 줄(36)만 들어가면 a
        #expect(RecordSymptomTreemap.fits(label, .a, in: CGSize(width: 80, height: 46), measure))
        #expect(!RecordSymptomTreemap.fits(RecordSymptomTreemap.Label(name: "설사", count: "1회"), .a, in: CGSize(width: 80, height: 46), measure))
    }

    @Test func 테두리는_oklch로_밝기와_선명함을_바꾼다() {
        // 개발 전달 8번 예 (메스꺼움) #82F6EF → 위 #C2FFFD · 아래 #5EDDD5
        let hex = { (rgb: RecordSymptomTreemap.RGB) in [rgb.red, rgb.green, rgb.blue].map { Int(($0 * 255).rounded()) } }
        let border = RecordSymptomTreemap.border(of: (0x82 / 255.0, 0xF6 / 255.0, 0xEF / 255.0))
        #expect(zip(hex(border.top), [0xC2, 0xFF, 0xFD]).allSatisfy { abs($0 - $1) <= 1 })
        #expect(zip(hex(border.bottom), [0x5E, 0xDD, 0xD5]).allSatisfy { abs($0 - $1) <= 1 })
    }

    @Test func 카드_원문은_검토_필요_표시를_빼고_보여준다() {
        func card(_ detail: String?) -> RecordSymptomCardItem {
            RecordSymptomCardItem(date: Date(), entry: SymptomEntryDisplay(
                id: UUID(), symptomType: .diarrhea, presence: .present, detail: detail))
        }
        #expect(card("[검토 필요] 하루 세 번이요").quote == "하루 세 번이요")
        #expect(card("배가 아파요").quote == "배가 아파요")
        #expect(card("[검토 필요]").quote == nil)
        #expect(card(nil).quote == nil)
    }
}
