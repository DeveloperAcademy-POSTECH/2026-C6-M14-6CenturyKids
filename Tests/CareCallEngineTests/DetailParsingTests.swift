import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 증상 기록 저장용 변환 (#84): 부위 낱말 → BodyPart·BodySide, 횟수·기간 답 → 숫자. 가상 발화만
struct BodyPartDictionaryTests {
    let dictionary = try! fixture(BodyPartDictionary.self, "body_parts")

    @Test(arguments: [
        ("손", BodyPart.armHand), ("발", .legFoot), ("허벅지 안쪽", .legFoot), ("종아리", .legFoot),
        ("손목", .armHand), ("발목", .legFoot), ("목", .neck), ("발등", .legFoot), ("등", .backLowerBack),
        ("입안", .headFace), ("배꼽", .abdomen), ("양손", .armHand), ("왼쪽 발", .legFoot), ("어깨", .shoulder),
    ])
    func 부위_낱말을_BodyPart로(word: String, part: BodyPart) {
        #expect(dictionary.bodyPart(for: word) == part)
    }

    @Test(arguments: ["모르겠어요", "여기요", ""])
    func 사전에_없으면_nil(word: String) {
        #expect(dictionary.bodyPart(for: word) == nil)
    }

    @Test(arguments: [
        ("왼손", BodySide.left), ("왼쪽 발", .left), ("오른발", .right), ("양손", .both), ("양쪽 발", .both), ("가운데 배", .center),
    ])
    func 앞에_말한_좌우(word: String, side: BodySide) {
        #expect(dictionary.bodySide(for: word) == side)
    }

    @Test(arguments: ["손", "허벅지 안쪽", "등"])
    func 좌우를_말하지_않으면_nil(word: String) {
        #expect(dictionary.bodySide(for: word) == nil)
    }

    @Test func 사전의_이름은_Domain_값이고_낱말은_한_부위에만() {
        #expect(dictionary.parts.keys.allSatisfy { BodyPart(rawValue: $0) != nil })
        #expect(dictionary.sides.keys.allSatisfy { BodySide(rawValue: $0) != nil })
        let words = dictionary.parts.values.flatMap { $0 }
        #expect(words.count == Set(words).count)
    }
}

struct DetailNumberTests {
    @Test(arguments: [
        ("하루 다섯 번이요", 5), ("하루 두 번이요", 2), ("하루에 두 번쯤 그랬지예", 2), ("어제 두 번이요", 2),
        ("어제 한 번 그랬어요", 1), ("한 3번?", 3), ("세번", 3), ("열두 번", 12), ("하루 열 번", 10), ("3회", 3),
        ("한 번 넘어졌어요", 1), ("두 번 했는데 이상해요", 2), ("세 번 했어요 넘 힘들어요", 3), ("두 번이요, 이상하게 계속 그래요", 2),
        ("세 번 했는데 기분이 좀 이상했어요", 3), ("하루 두 번, 밥을 넘기기도 힘들어요", 2), ("저번 이상으로 세 번", 3),
        ("한 번 더 넘어졌어요", 1),
    ])
    func 분명한_횟수를_읽는다(text: String, count: Int) {
        #expect(NumberParser.count(in: text) == count)
    }

    @Test(arguments: [
        "토하지는 않고 하루 한두 번 그래요", "하루에 서너 번이요", "어제부터요, 하루 두세 번 정도요", "2~3번",
        "두 번이나 세 번", "두 번째예요", "사흘 전부터요", "이번 주부터요", "여러 번", "150번", "몇 번 했어요",
        "열 번 넘게", "10번 이상이요", "다섯 번 넘었어요", "10번은 넘었어요", "열 번도 넘게요", "열 번 좀 넘게",
        "열 번 훨씬 넘어요", "열 번 넘어갔어요", "열 번이 넘어요", "열 번 남짓", "적어도 세 번", "최소 다섯 번", "열 번 넘지는 않았어요",
        "열 번 가까이", "열 번 안 되게", "다섯 번 이하", "열 번 미만", "열 번 안팎",
    ])
    func 모호하거나_횟수가_아니면_nil(text: String) {
        #expect(NumberParser.count(in: text) == nil)
    }
}
