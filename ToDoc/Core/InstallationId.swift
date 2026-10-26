//
//  InstallationId.swift
//  ToDoc
//
//  Created by 앤디 on 10/25/26.
//

import Foundation

enum InstallationId {
    static let value: String = {
        let key = "installation_id"
        
        if let saved = UserDefaults.standard.string(forKey: key) {
            return saved
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }()
}
