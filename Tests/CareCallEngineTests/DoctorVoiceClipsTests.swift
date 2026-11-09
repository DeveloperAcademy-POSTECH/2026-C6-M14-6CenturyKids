import Foundation
import Testing
@testable import ToDocCareCall

/// 케어콜이 하는 말이 모두 의사 선생님 녹음 조각으로 읽히는지 (문구를 바꾸면 그 조각을 다시 녹음해야 한다)
struct DoctorVoiceClipsTests {
    @Test func 맞장구와_문장_끝에서_나눈다() {
        #expect(DoctorVoiceClips.pieces(of: "알겠어요, 기억해 둘게요. 이제 다른 증상들에 대해서 물어볼게요.")
                == ["알겠어요.", "기억해 둘게요.", "이제 다른 증상들에 대해서 물어볼게요."])
        // 문장 가운데 쉼표는 나누지 않는다
        #expect(DoctorVoiceClips.pieces(of: "지금 바로 담당 병원에 연락하시거나, 위급하시면 119에 전화해 주세요.")
                == ["지금 바로 담당 병원에 연락하시거나, 위급하시면 119에 전화해 주세요."])
        #expect(DoctorVoiceClips.pieces(of: "문장 부호가 없는 말") == nil)
    }

    @Test func 조각_하나라도_녹음이_없으면_문장을_기기_음성으로() {
        let clips = DoctorVoiceClips(names: ["알겠어요.": "ack_okay"])
        #expect(clips.clipNames(for: "알겠어요.") == ["ack_okay"])
        #expect(clips.clipNames(for: "알겠어요, 기록해 둘게요.") == nil)
    }

    @Test func 케어콜이_하는_말은_모두_녹음_파일이_있다() throws {
        let config = try fixture(CareCallConfig.self, "side_effects")
        let rules = try fixture(EmergencyRules.self, "emergency_rules")
        let clips = try fixture(DoctorVoiceClips.self, "doctor_voice")
        let t = config.openingTransition, f = config.followUpCall
        var spoken = [config.aiVoiceNotice, config.openingQuestion, config.openingFollowUp, t.fine, t.noted, t.afterFollowUp,
                      f.question, f.followUp, f.noted, f.notedAndResume, f.resume, f.notedOther, f.unchanged,
                      config.locationPrompt, config.repeatPrefix, config.unsureNoted,
                      config.otherQuestion, config.otherFollowUp, config.otherDetail.question, config.otherDetail.recorded,
                      rules.closingMessage, rules.confirmQuestion, rules.message, rules.crisisMessage]
        for effect in config.effects {
            spoken += [effect.ask] + effect.details.map(\.question)
                + [config.returnPrefix(for: effect), config.mentionedPrefix(for: effect), config.notedOtherPrefix(for: effect)]
        }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "ToDoc/Resources/DoctorVoice")
        for text in spoken {
            let names = clips.clipNames(for: text)
            #expect(names != nil, "녹음 없는 조각이 있음: \(text)")
            for name in names ?? [] {
                #expect(FileManager.default.fileExists(atPath: folder.appending(path: "\(name).m4a").path), "파일 없음: \(name).m4a")
            }
        }
    }
}
