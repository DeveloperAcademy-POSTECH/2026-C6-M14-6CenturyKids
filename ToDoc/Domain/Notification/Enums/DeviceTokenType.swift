//
//  DeviceTokenType.swift
//  ToDoc
//
//  Created by 앤디 on 10/25/26.
//

nonisolated public enum DeviceTokenType: String, Codable {
    case notification = "notification"
    case liveActivityStart = "liveActivityStart"
    case liveActivityUpdate = "liveActivityUpdate"
}
