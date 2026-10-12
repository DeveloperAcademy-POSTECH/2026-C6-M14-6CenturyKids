import XCTest
@testable import CareCallPresentation

@MainActor
final class CareCallPreparationCancellationTests: XCTestCase {
    func testExplicitCancelReachesPreparationOperation() async throws {
        let started = expectation(description: "operation started")
        let cancelled = expectation(description: "operation received cancellation")
        var response: CheckedContinuation<Void, Error>?
        let model = CareCallPreparationViewModel { _ in
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    response = $0
                    started.fulfill()
                }
            } onCancel: { cancelled.fulfill() }
        }
        let request = Task { await model.prepare() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        model.cancel()
        await fulfillment(of: [cancelled], timeout: 0.5)
        pending.resume()
        await request.value
        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(model.canStart)
    }

    func testCallerCancellationReachesPreparationOperation() async throws {
        let started = expectation(description: "operation started")
        let cancelled = expectation(description: "operation received cancellation")
        var response: CheckedContinuation<Void, Error>?
        let model = CareCallPreparationViewModel { _ in
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    response = $0
                    started.fulfill()
                }
            } onCancel: { cancelled.fulfill() }
        }
        let request = Task { await model.prepare() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        request.cancel()
        await fulfillment(of: [cancelled], timeout: 0.5)
        pending.resume()
        await request.value
        XCTAssertEqual(model.state, .idle)
    }

    func testOldSuccessCannotClearNewPreparationOrItsCancellation() async throws {
        let firstStarted = expectation(description: "first operation started")
        let secondStarted = expectation(description: "second operation started")
        let secondCancelled = expectation(description: "second operation received cancellation")
        var responses: [CheckedContinuation<Void, Error>] = []
        var attempts = 0
        let model = CareCallPreparationViewModel { _ in
            attempts += 1
            let attempt = attempts
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    responses.append($0)
                    (attempt == 1 ? firstStarted : secondStarted).fulfill()
                }
            } onCancel: {
                if attempt == 2 { secondCancelled.fulfill() }
            }
        }
        let first = Task { await model.prepare() }
        await fulfillment(of: [firstStarted], timeout: 2)
        model.cancel()
        let second = Task { await model.prepare() }
        await fulfillment(of: [secondStarted], timeout: 2)
        responses[0].resume()
        await first.value
        XCTAssertEqual(model.state, .preparing(.permissions))
        XCTAssertFalse(model.canStart)
        model.cancel()
        await fulfillment(of: [secondCancelled], timeout: 0.5)
        responses[1].resume()
        await second.value
        XCTAssertEqual(model.state, .idle)
    }

}
