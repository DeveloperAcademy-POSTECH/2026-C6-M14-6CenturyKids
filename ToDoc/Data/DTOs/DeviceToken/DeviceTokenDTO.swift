//
//  DeviceTokenDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/16/26.
//

import Foundation

struct DeviceTokenDTO: Codable {
    let id: UUID
    let userId: UUID
    let updatedAt: Date
    let token: String
    let platform: String
}

extension DeviceTokenDTO {
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case userId = "user_id"
        case updatedAt = "updated_at"
        case token = "token"
        case platform = "platform"
    }
}
