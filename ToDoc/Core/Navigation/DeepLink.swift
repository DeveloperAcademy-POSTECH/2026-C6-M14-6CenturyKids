//
//  DeepLink.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation

enum DeepLink: Equatable {
    case careCall(autoStartVoice: Bool)
    case painRecord
    /// 병원 도착 알림을 누르면 진료 전 기록 작성 화면을 연다
    case previsit

    init?(url: URL) {
        guard url.scheme == "todoc",
              url.host == "record" else {
            return nil
        }

        if url.path == "/pain" {
            self = .painRecord
            return
        }

        if url.path == "/previsit" {
            self = .previsit
            return
        }

        guard url.path == "/symptoms" else {
            return nil
        }

        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )
        
        let startsVoice = components?.queryItems?.contains {
            $0.name == "mode" && $0.value == "voice"
        } == true
        
        self = .careCall(autoStartVoice: startsVoice)
    }
}
