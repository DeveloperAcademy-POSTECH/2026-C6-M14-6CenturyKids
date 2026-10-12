import XCTest
@testable import CareCallPresentation

@MainActor
final class CareCallPreparationFailureTests: XCTestCase {
    func testModelMissingRemainsDistinctFromUnconnectedService() async {
        let model = CareCallPreparationViewModel { _ in throw CareCallPreparationError.modelMissing }
        await model.prepare()
        XCTAssertEqual(model.state, .modelMissing)
        XCTAssertFalse(model.canStart)
        XCTAssertFalse(model.isPreparing)
    }

    func testModelLoadFailureCanBeRetriedWithoutStaleFailure() async {
        var attempts = 0
        let model = CareCallPreparationViewModel { _ in
            attempts += 1
            if attempts == 1 { throw CareCallPreparationError.modelLoadFailed }
        }
        await model.prepare()
        XCTAssertEqual(model.state, .modelLoadFailed)
        XCTAssertFalse(model.canStart)
        await model.prepare()
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(attempts, 2)
    }

    func testUnsupportedSpeechRecognitionRemainsDistinctAndCannotStart() async {
        let model = CareCallPreparationViewModel { _ in
            throw CareCallPreparationError.speechRecognitionUnsupported
        }
        await model.prepare()
        XCTAssertEqual(model.state, .speechRecognitionUnsupported)
        XCTAssertFalse(model.canStart)
    }

    func testAlreadyCancelledCallerDoesNotStartPreparation() async {
        var attempts = 0
        let model = CareCallPreparationViewModel { _ in attempts += 1 }
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await model.prepare()
        }
        await request.value
        XCTAssertEqual(attempts, 0)
        XCTAssertEqual(model.state, .idle)
    }
}
