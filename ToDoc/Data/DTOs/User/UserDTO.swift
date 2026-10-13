//
//  UserDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/12/26.
//

import Foundation

struct UserDTO: Codable {
    let id: UUID
    let name: String
    let birthday: String
    let sex: String
    
    init(user: User) {
        id = user.id
        name = user.name
        birthday = Self.formatter().string(from: user.birthday)
        sex = user.sex.rawValue
    }
    
    func toDomain(email: String) throws -> User {
        guard let birthdayDate = Self.formatter().date(from: birthday) else {
            throw MappingError.invalidBirthday(birthday)
        }
        
        guard let domainSex = Sex(rawValue: sex) else {
            throw MappingError.invalidSex(sex)
        }
        
        return try User(id: id, email: email, name: name, birthday: birthdayDate, sex: domainSex)
    }
}

extension UserDTO {
    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        
        return formatter
    }
    
    enum CodingKeys: String, CodingKey {
            case id = "id"
            case name = "name"
            case birthday = "birthday"
            case sex = "sex"
    }
}
