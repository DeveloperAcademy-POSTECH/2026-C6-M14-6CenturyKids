//
//  DeepLink.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation

enum DeepLink: Equatable {
    case careCall
    
    init?(url: URL) {
        guard url.scheme == "todoc",
              url.host == "record",
              url.path == "/symptoms" else {
            return nil
        }
        
        self = .careCall
    }
}
