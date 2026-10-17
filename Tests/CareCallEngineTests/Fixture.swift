import Foundation
@testable import ToDocFeatures

/// 앱과 같은 설정 파일(ToDoc/Resources/Config)을 읽는다
func fixture<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appending(path: "ToDoc/Resources/Config/\(name).json")
    return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
}
