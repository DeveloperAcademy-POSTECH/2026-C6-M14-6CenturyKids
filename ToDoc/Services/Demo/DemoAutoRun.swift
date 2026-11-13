//
//  DemoAutoRun.swift
//  ToDoc
//
//  Created by seokho on 11/13/26.
//

import Foundation
import OSLog

/// 시연·측정용: 자동 환자(DemoAutoPatient)로 음성 통화를 화면 없이 여러 판 돌린다. 기록은 저장하지 않는다.
/// Mac에서 앱을 띄울 때 환경 변수로 시킨다 (devicectl은 DEVICECTL_CHILD_ 접두어를 붙여 넘긴다):
/// - AUTO_PATIENT=1: 시나리오를 돌린다. AUTO_SCEN=S01,S03 (없으면 전부), AUTO_SPECULATE=1|0 (미리 분석하기, 없으면 설정대로)
/// - AUTO_SPEECH_CHECK=1: 시나리오에 쓰는 문장들이 합성 음성으로 제대로 받아써지는지만 본다 ("문장;문장"을 주면 그 문장들만)
/// 결과는 표준 출력("AUTO …")과 Documents/auto-patient.txt에 남기고 앱을 끝낸다
enum DemoAutoRun {
    struct Scenario {
        let id: String
        let title: String
        /// 질문 종류 → 할 말. 종류: opening, 증상 id(유무 질문), location, count, onset, amount, other, otherFollowUp, confirm.
        /// 없는 종류는 fallback을 쓴다. "|"에서는 1초 쉰다
        let answers: [String: String]
    }

    static let scenarios: [Scenario] = [
        Scenario(id: "S01", title: "전부 없음 (긴 답)", answers: [
            "nausea_vomiting": "아니요 속 편안합니다", "constipation": "대변은 날마다 잘 보고 있어요", "diarrhea": "변은 단단하게 잘 나와요",
            "stomatitis": "입속은 하나도 안 헐었어요", "neuropathy": "손발은 괜찮아요", "rash_pruritus": "아니요 깨끗해요",
            "dehydration_nutrition": "식사는 평소대로 해요",
        ]),
        Scenario(id: "S02", title: "전부 없음 (짧은 답)", answers: [:]),
        Scenario(id: "S03", title: "구토 있음", answers: ["nausea_vomiting": "네 어제 저녁에 토했어요"]),
        Scenario(id: "S04", title: "설사 있음", answers: ["diarrhea": "어제부터 설사를 해요", "count": "세 번이요"]),
        Scenario(id: "S05", title: "저림 있음, 부위를 함께 말함", answers: ["neuropathy": "양쪽 발이 저려요", "onset": "일주일 전부터요"]),
        Scenario(id: "S06", title: "피부 있음, 부위를 따로 물음", answers: ["rash_pruritus": "네 가려워요", "location": "왼쪽 팔이요"]),
        Scenario(id: "S07", title: "식사 줄어듦", answers: ["dehydration_nutrition": "밥을 반 공기도 못 먹어요"]),
        Scenario(id: "S08", title: "쉬었다 이어 말하기", answers: [
            "constipation": "대변은 날마다|잘 보고 있어요", "stomatitis": "입속은 하나도|안 헐었어요", "dehydration_nutrition": "식사는 평소대로|해요",
        ]),
        Scenario(id: "S09", title: "첫 질문에서 증상을 말함", answers: ["opening": "어제부터 속이 울렁거려요"]),
        Scenario(id: "S10", title: "그 밖에 증상", answers: ["other": "눈이 자주 충혈돼요"]),
    ]

    private static let fallback = [
        "opening": "괜찮아요", "location": "손이요", "count": "두 번이요", "onset": "어제부터요", "amount": "절반 정도요",
        "other": "없어요", "otherFollowUp": "없어요", "confirm": "아니요",
    ]
    /// 유무 질문에 따로 정한 답이 없을 때
    private static let no = "아니요"
    /// 한 판이 이보다 길어지면 끊는다 (같은 질문을 되풀이하는 경우)
    private static let limit: Duration = .seconds(300)
    /// 돌린 통화 서비스를 앱이 끝날 때까지 잡아 둔다. 판이 끝나자마자 놓으면 AI 음성 재생기가 마지막 조각을 정리하는 중에 없어져
    /// 앱이 죽었다 (MediaToolbox에서 EXC_BAD_ACCESS, 2026-11-13 실기기 7번째 판)
    private static var kept: [CareCallService] = []

    /// 시나리오에 나오는 모든 문장 (쉬는 자리는 이어 붙여서)
    static var allSentences: [String] {
        var seen = Set<String>()
        return (scenarios.flatMap { $0.answers.values } + fallback.values + [no])
            .map { $0.replacingOccurrences(of: String(DemoAutoPatient.pauseMark), with: " ") }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    static func runIfRequested(container: DependencyContainer) async {
        let env = ProcessInfo.processInfo.environment
        if let check = env["AUTO_SPEECH_CHECK"] {
            // "1"이면 시나리오 문장 전부, 아니면 ";"로 나눈 문장들 (바꿀 표현을 미리 볼 때)
            _ = await DemoSpeechCheck.run(sentences: check == "1" ? allSentences : check.split(separator: ";").map(String.init))
            exit(0)
        }
        guard env["AUTO_PATIENT"] != nil else { return }
        let wanted = env["AUTO_SCEN"].map { Set($0.split(separator: ",").map(String.init)) }
        let chosen = scenarios.filter { wanted?.contains($0.id) ?? true }
        // 이 실행 동안만: 7개를 모두 묻게 하고, 미리 분석하기는 시킨 대로 둔다
        let defaults = UserDefaults.standard
        let keys = [DemoCareCallPlan.enabledKey, FoundationModelsCareCallAdapter.speculationKey]
        let saved = keys.map { defaults.object(forKey: $0) }
        defaults.set(false, forKey: DemoCareCallPlan.enabledKey)
        if let speculate = env["AUTO_SPECULATE"] { defaults.set(speculate == "1", forKey: FoundationModelsCareCallAdapter.speculationKey) }
        var lines = ["[자동] 시작 · 시나리오 \(chosen.count)개 · 미리 분석 \(FoundationModelsCareCallAdapter.speculationEnabled ? "켬" : "끔")"]
        note(lines[0])
        for scenario in chosen {
            lines += await run(scenario, container: container)
        }
        for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
        note("[자동] 끝")
        try? lines.joined(separator: "\n").write(to: URL.documentsDirectory.appending(path: "auto-patient.txt"), atomically: true, encoding: .utf8)
        exit(0)
    }

    /// 한 판을 돌리고, 그 판의 줄(진행 + 시간 로그)을 돌려준다
    private static func run(_ scenario: Scenario, container: DependencyContainer) async -> [String] {
        var lines: [String] = []
        func say(_ line: String) {
            lines.append(line)
            note(line)
        }
        say("[자동] === \(scenario.id) \(scenario.title)")
        let started = Date.now
        do {
            let config = try Bundle.main.decodeJSON(CareCallConfig.self, named: "side_effects")
            let rules = try Bundle.main.decodeJSON(EmergencyRules.self, named: "emergency_rules")
            let patient = DemoAutoPatient()
            let service = try container.makeCareCallService(recorder: patient)
            kept.append(service)
            try await service.requestMicrophone()
            try await service.loadModel()
            try await service.prepareSpeech()
            await patient.rehearse(Array(scenario.answers.values) + Array(fallback.values) + [no])
            _ = try service.begin(patientId: UUID(), previous: nil)
            var question = ""
            let watchdog = Task {
                try? await Task.sleep(for: limit)
                guard !Task.isCancelled else { return }
                note("[자동] 너무 길어져 끊음")
                await service.stop()
            }
            let outcome = try await service.run { activity in
                switch activity {
                case .speaking(let text):
                    question = text
                case .listening:
                    let kind = kind(of: question, config: config, rules: rules)
                    let answer = scenario.answers[kind] ?? fallback[kind] ?? no
                    say("[자동] 질문(\(kind)) ‘\(question)’ → 답 ‘\(answer)’")
                    // 사람이 대답을 시작하기까지의 틈
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        patient.say(answer)
                    }
                case .heard(let text):
                    say("[자동] 들린 말 ‘\(text)’")
                default:
                    break
                }
            }
            watchdog.cancel()
            say("[자동] 결과 \(describe(outcome))")
        } catch {
            say("[자동] 실패 \(String(describing: error))")
        }
        // 이 판에서 남은 시간 로그([듣기]·[턴]·[미리]·[FM])를 함께 내보낸다
        let timing = timingLines(since: started)
        timing.forEach(note)
        return lines + timing
    }

    /// AI가 한 말이 어떤 질문인지. 앞에 붙는 말("죄송해요, 다시 한 번…")이 있어 포함 여부로 본다
    private static func kind(of question: String, config: CareCallConfig, rules: EmergencyRules) -> String {
        if question.contains(rules.confirmQuestion) { return "confirm" }
        if question.contains(config.locationPrompt) { return "location" }
        if question.contains("몇 번") { return "count" }
        if question.contains("얼마나 적게") { return "amount" }
        if question.contains("언제부터") { return "onset" }
        if let effect = config.effects.first(where: { question.contains($0.ask) }) { return effect.id }
        if question.contains(config.otherFollowUp) { return "otherFollowUp" }
        if question.contains(config.otherQuestion) { return "other" }
        return "opening"
    }

    private static func describe(_ outcome: CareCallOutcome) -> String {
        func record(_ r: SymptomRecord?) -> String {
            guard let r else { return "기록 없음" }
            return r.symptoms.map { entry in
                let extras = [entry.bodyPart.map { "\($0)" }, entry.occurrenceCount.map { "\($0)번" }, entry.detail].compactMap(\.self)
                return "\(entry.symptomType)=\(entry.presence)" + (extras.isEmpty ? "" : "(\(extras.joined(separator: ", ")))")
            }.joined(separator: " · ")
        }
        switch outcome {
        case .completed(let r): return "끝까지 마침: " + record(r)
        case .emergencyEnded(let r): return "응급 안내로 끝남: " + record(r)
        case .interrupted(let r): return "중간에 끊김: " + record(r)
        }
    }

    /// 이 앱이 since 뒤로 남긴 ToDoc 로그
    private static func timingLines(since: Date) -> [String] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier),
              let entries = try? store.getEntries(at: store.position(date: since), matching: NSPredicate(format: "subsystem == %@", "ToDoc")) else { return [] }
        let time = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).secondFraction(.fractional(3))
        return entries.compactMap { $0 as? OSLogEntryLog }
            .filter { $0.date >= since && $0.category != "SpeechCheck" }
            .map { "\($0.date.formatted(time)) \($0.composedMessage)" }
    }

    private static func note(_ line: String) {
        print("AUTO " + line)
        fflush(stdout)
    }
}
