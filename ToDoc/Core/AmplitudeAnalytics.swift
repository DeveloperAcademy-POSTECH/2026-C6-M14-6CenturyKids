import AmplitudeSwift
import Foundation
import OSLog

/// 키는 로컬 빌드 설정에서만 주입하며, 값이나 SDK 설정 전체를 로그로 남기지 않습니다.
@MainActor
final class AmplitudeAnalytics {
    private let client: Amplitude?
    private let logger = Logger(subsystem: "ToDoc", category: "Analytics")

    init(bundle: Bundle = .main) {
        // Preview와 단위 테스트에서는 수집하지 않습니다.
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            client = nil
            return
        }

        guard let value = bundle.object(forInfoDictionaryKey: "AmplitudeAPIKey") as? String else {
            client = nil
            logger.notice("Analytics disabled: configuration is missing.")
            return
        }
        let apiKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, !apiKey.contains("$(") else {
            client = nil
            logger.notice("Analytics disabled: configuration is unresolved.")
            return
        }

        client = Amplitude(configuration: Configuration(
            apiKey: apiKey,
            autocapture: [],
            enableAutoCaptureRemoteConfig: false
        ))
        logger.notice("Analytics initialized. Automatic event capture is disabled.")
    }

    func track(_ eventName: String, properties: [String: Any] = [:]) {
        guard let client else { return }

        var eventProperties = properties
        eventProperties["schema_version"] = 1
        client.track(eventType: eventName, eventProperties: eventProperties)
    }

    /// 개발자가 실행 인자를 지정한 경우에만 가상 이벤트 한 건을 전송합니다.
    func sendIntegrationTestIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-amplitude-smoke-test"),
              let client else { return }
        client.track(eventType: "analytics_integration_test", eventProperties: [
            "schema_version": 1,
            "source": "manual_debug_test"
        ])
        client.flush()
        logger.notice("Analytics integration test queued; verify receipt in Amplitude.")
        #endif
    }
}
