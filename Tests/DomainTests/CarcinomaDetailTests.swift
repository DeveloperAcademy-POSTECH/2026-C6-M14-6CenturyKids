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

    func testUpdatingStageKeepsFreeTextAndChangingCancerClearsIt() {
        var detail = CarcinomaDetail(carcinoma: .other, stage: .unknown, otherName: "  연부조직 육종  ")
        detail.updateStage(.stage2)
        XCTAssertEqual(detail.carcinomaDisplayName, "연부조직 육종")
        detail.updateCarcinomaType(.lung)
        XCTAssertEqual(detail.carcinomaDisplayName, "폐암")
        XCTAssertNil(detail.otherName)
        XCTAssertEqual(detail.stage, .stage2)
    }
}
