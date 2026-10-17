import Foundation

/// 사용자 정보의 값 스냅샷입니다. 변경 실패 시 기존 값을 보존합니다.
nonisolated public struct User: Sendable {
    public let id: UUID
    public private(set) var name: String
    public private(set) var birthday: Date
    public private(set) var sex: Sex

    public var age: Int { age(on: Date(), calendar: DomainDateRules.calendar) }

    /// 이메일은 인증 저장소가 관리합니다. 현재 UserDTO의 호출 형식에 맞춘 생성자입니다.
    /// 기존 email 인자 생성자는 호환을 위해 유지하며, 두 경로 모두 같은 검증을 거칩니다.
    public init(id: UUID, name: String, birthday: Date, sex: Sex) throws {
        try self.init(id: id, name: name, birthday: birthday, sex: sex,
                      now: Date(), calendar: DomainDateRules.calendar)
    }

    public init(id: UUID, email: String, name: String, birthday: Date, sex: Sex) throws {
        try self.init(id: id, name: name, birthday: birthday, sex: sex,
                      now: Date(), calendar: DomainDateRules.calendar)
    }

    init(id: UUID, name: String, birthday: Date, sex: Sex,
         now: Date, calendar: Calendar) throws {
        let validName = try DomainValidation.name(name, maximum: 10)
        try DomainDateRules.validateBirthday(birthday, now: now, calendar: calendar)
        self.id = id
        self.name = validName
        self.birthday = birthday
        self.sex = sex
    }

    public mutating func updateName(_ name: String) throws {
        self.name = try DomainValidation.name(name, maximum: 10)
    }

    public mutating func updateBirthday(_ birthday: Date) throws {
        try updateBirthday(birthday, now: Date(), calendar: DomainDateRules.calendar)
    }

    mutating func updateBirthday(_ birthday: Date, now: Date, calendar: Calendar) throws {
        try DomainDateRules.validateBirthday(birthday, now: now, calendar: calendar)
        self.birthday = birthday
    }

    public mutating func updateSex(_ sex: Sex) {
        self.sex = sex
    }

    func age(on date: Date, calendar: Calendar) -> Int {
        DomainDateRules.age(birthday: birthday, now: date, calendar: calendar)
    }
}
