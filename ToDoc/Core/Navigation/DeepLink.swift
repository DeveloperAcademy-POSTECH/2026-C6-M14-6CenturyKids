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

    init?(url: URL) {
        guard url.scheme == "todoc",
              url.host == "record" else {
            return nil
        }

        if url.path == "/pain" {
            self = .painRecord
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
