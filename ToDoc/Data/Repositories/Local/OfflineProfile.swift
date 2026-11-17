import Foundation

/// 기기에만 저장하는 모드에서 쓰는 고정된 체험자입니다. 계정·비밀번호·서버 세션이 없습니다.
enum OfflineProfile {
    static let id = UUID(uuidString: "C6000000-0000-4000-8000-000000000001")!

    /// 체험자 정보가 기기에 없으면 처음 한 번 만듭니다.
    static func prepare(store: LocalFileStore) throws {
        try store.locked {
            if try store.read(UserDTO.self, collection: "users", id: id) == nil {
                let user = try User(id: id, name: "체험자", birthday: Date(timeIntervalSince1970: 0), sex: .female)
                try store.write(UserDTO(user: user), collection: "users", id: id)
            }
            if try store.read(PatientDTO.self, collection: "patients", id: id) == nil {
                let user = try store.read(UserDTO.self, collection: "users", id: id)!.toDomain()
                try store.write(PatientDTO(patient: Patient(user: user, doctorId: nil, disease: nil)), collection: "patients", id: id)
            }
        }
    }
}
