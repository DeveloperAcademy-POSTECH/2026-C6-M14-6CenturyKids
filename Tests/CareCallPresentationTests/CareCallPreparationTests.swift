import XCTest
@testable import CareCallPresentation

@MainActor
final class CareCallPreparationTests: XCTestCase {
    func testUnconnectedPreparationNeverBecomesReady() async {
        let model = CareCallPreparationViewModel()
        await model.prepare()
        XCTAssertEqual(model.state, .unavailable)
        XCTAssertFalse(model.canStart)
        XCTAssertFalse(model.isPreparing)
    }

    func testProgressAndReadinessFollowActualOperation() async throws {
        let started = expectation(description: "preparation requested")
        var report: CareCallPreparationViewModel.Progress?
        var response: CheckedContinuation<Void, Error>?
        let model = CareCallPreparationViewModel { progress in
            report = progress
            try await withCheckedThrowingContinuation {
                response = $0
                started.fulfill()
            }
        }
        let request = Task { await model.prepare() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        let progress = try XCTUnwrap(report)
        XCTAssertEqual(model.state, .preparing(.permissions))
        XCTAssertFalse(model.canStart)
        progress(.model)
        XCTAssertEqual(model.state, .preparing(.model))
        progress(.speechAssets)
        XCTAssertEqual(model.state, .preparing(.speechAssets))
        XCTAssertTrue(model.isPreparing)
        pending.resume()
        await request.value
        XCTAssertEqual(model.state, .ready)
        XCTAssertTrue(model.canStart)
        progress(.model)
        XCTAssertEqual(model.state, .ready, "준비 완료 후 늦은 진행 보고를 무시해야 합니다.")
    }

    func testPermissionDenialCanBeRetriedAfterReturningFromSettings() async {
        var attempts = 0
        let model = CareCallPreparationViewModel { _ in
            attempts += 1
            if attempts == 1 { throw CareCallPreparationError.microphoneDenied }
        }
        await model.prepare()
        XCTAssertEqual(model.state, .microphoneDenied)
        XCTAssertFalse(model.canStart)
        await model.prepare()
        XCTAssertEqual(model.state, .ready)
    }

    func testFailureDoesNotBecomeReadyAndSuccessfulRetryClearsIt() async {
        var attempts = 0
        let model = CareCallPreparationViewModel { _ in
            attempts += 1
            if attempts == 1 { throw NSError(domain: "preparation", code: 1) }
        }
        await model.prepare()
        XCTAssertEqual(model.state, .failed)
        XCTAssertFalse(model.canStart)
        await model.prepare()
        XCTAssertEqual(model.state, .ready)
    }

    func testDuplicatePreparationDoesNotStartAnotherOperation() async throws {
        let started = expectation(description: "preparation requested")
        var response: CheckedContinuation<Void, Error>?
        var attempts = 0
        let model = CareCallPreparationViewModel { _ in
            attempts += 1
            try await withCheckedThrowingContinuation {
                response = $0
                started.fulfill()
            }
        }
        let request = Task { await model.prepare() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        await model.prepare()
        XCTAssertEqual(attempts, 1)
        pending.resume()
        await request.value
        await model.prepare()
        XCTAssertEqual(attempts, 1, "이미 준비됐다면 다시 준비하지 않습니다.")
    }

    func testCancelledProgressAndFailureCannotOverwriteNewReadyState() async throws {
        let started = expectation(description: "first preparation requested")
        var report: CareCallPreparationViewModel.Progress?
        var response: CheckedContinuation<Void, Error>?
        var attempts = 0
        let model = CareCallPreparationViewModel { progress in
            attempts += 1
            if attempts == 1 {
                report = progress
                try await withCheckedThrowingContinuation {
                    response = $0
                    started.fulfill()
                }
            }
        }
        let oldRequest = Task { await model.prepare() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        model.cancel()
        XCTAssertEqual(model.state, .idle)
        await model.prepare()
        report?(.speechAssets)
        pending.resume(throwing: CareCallPreparationError.microphoneDenied)
        await oldRequest.value
        XCTAssertEqual(model.state, .ready)
    }

    func testTaskCancellationCannotMakePreparationReady() async throws {
        let started = expectation(description: "preparation requested")
        var response: CheckedContinuation<Void, Error>?
        let model = CareCallPreparationViewModel { _ in
            try await withCheckedThrowingContinuation {
                response = $0
                started.fulfill()
            }
        }
        let request = Task { await model.prepare() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        request.cancel()
        pending.resume()
        await request.value
        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(model.canStart)
    }

    func testCancellationErrorReturnsToIdle() async {
        let model = CareCallPreparationViewModel { _ in throw CancellationError() }
        await model.prepare()
        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(model.isPreparing)
    }
}
