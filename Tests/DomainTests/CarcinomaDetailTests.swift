import XCTest
import ToDocDomain

final class CarcinomaDetailTests: XCTestCase {
    func testUpdatingCancerAndStagePreservesTheOtherValue() {
        var detail = CarcinomaDetail(carcinoma: .breast, stage: .stage1)
        detail.updateCarcinomaType(.lung)
        XCTAssertEqual(detail.carcinoma, .lung)
        XCTAssertEqual(detail.stage, .stage1)
        detail.updateStage(.stage4)
        XCTAssertEqual(detail.carcinoma, .lung)
        XCTAssertEqual(detail.stage, .stage4)
    }
}
