import Foundation

nonisolated struct HomeGreeting: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    /// 홈 안내 문구입니다. 실제 의료진 코멘트나 기록 저장 결과가 아닙니다.
    static let all: [HomeGreeting] = [
        .init(id: 0, text: "오늘도 함께해요. 파이팅!"),
        .init(id: 1, text: "오늘 하루는 어떠셨어요?"),
        .init(id: 2, text: "시간 괜찮으시면 오늘의 안부를 남겨주세요."),
        .init(id: 3, text: "오늘 이야기를 기록해보는거 어때요?"),
        .init(id: 4, text: "기록은 잘 남겨뒀다가 선생님께 전달할게요."),
        .init(id: 5, text: "밥은 꼭꼭 챙겨 먹어요"),
        .init(id: 6, text: "오늘 기분은 어때요?"),
        .init(id: 7, text: "오늘 식사는 어떠셨어요?"),
        .init(id: 8, text: "벌써 잘 시간이네요."),
        .init(id: 9, text: "오늘은 어떤 하루를 보내고 계세요?")
    ]
    static func pick(excluding previous: HomeGreeting?, chooseIndex: (Int) -> Int) -> HomeGreeting {
        let candidates = all.filter { $0.id != previous?.id }
        let index = chooseIndex(candidates.count)
        precondition(candidates.indices.contains(index), "Greeting chooser must return a candidate index")
        return candidates[index]
    }
}
