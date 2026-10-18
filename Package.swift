// swift-tools-version: 6.0
import PackageDescription

// 앱의 Foundation 기반 Domain 소스를 별도 패키지에서도 검증합니다.
// 케어콜 대화 엔진도 앱 소스를 그대로 가져와 검증합니다 (모델·음성 없이, 가짜 분석기로).
let package = Package(
    name: "ToDocTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ToDocCoreErrors", path: "ToDoc/Core/Errors"),
        .target(name: "ToDocDomain", dependencies: ["ToDocCoreErrors"], path: "ToDoc/Domain"),
        .target(name: "AuthScreens", dependencies: ["ToDocDomain"], path: "ToDoc/Features/Auth/Presentation"),
        .testTarget(name: "AuthScreenTests", dependencies: ["AuthScreens"], path: "Tests/AuthScreenTests"),
        // 증상 화면 상태는 케어콜 ViewModel과 같은 대상(ToDocCareCall)에 있다 (소스가 두 대상에 겹치면 빌드 오류)
        .testTarget(name: "SymptomScreenTests", dependencies: ["ToDocCareCall", "ToDocDomain"], path: "Tests/SymptomScreenTests"),
        .testTarget(name: "DomainTests", dependencies: ["ToDocDomain", "ToDocCoreErrors"], path: "Tests/DomainTests"),
        // 통화 서비스(CareCallService)는 마이크 타입이 macOS 27 전용이라 넣지 않는다
        .target(name: "ToDocCareCall", dependencies: ["ToDocDomain"], path: "ToDoc",
                // 앱의 다른 파일은 빌드하지 않는다 (새 폴더가 생겨도 테스트가 깨지지 않게 sources로 고정, exclude는 경고 방지)
                exclude: [
                    "Application", "Domain", "Resources", "ToDoc.entitlements",
                    "Data/DTOs", "Data/Supabase", "Data/Repositories/Supabase", "Data/Repositories/Local",
                    "Data/Repositories/Protocols/AuthRepository.swift",
                    "Data/Repositories/Protocols/DeviceTokenRepository.swift",
                    "Data/Repositories/Protocols/DoctorRepository.swift", "Data/Repositories/Protocols/ExerciseRepository.swift",
                    "Data/Repositories/Protocols/HospitalRepository.swift", "Data/Repositories/Protocols/IntakeRepository.swift",
                    "Data/Repositories/Protocols/NotificationRepository.swift",
                    "Data/Repositories/Protocols/PainRepository.swift", "Data/Repositories/Protocols/PatientRepository.swift",
                    "Data/Repositories/Protocols/UserRepository.swift",
                    "Features/Auth", "Features/Home", "Features/Notification", "Features/Onboarding", "Features/Pain",
                    "Features/Patient", "Features/Records", "Features/Settings", "Features/Symptom/Views",
                    "Core/AppIntents", "Core/Dependency", "Core/Errors", "Core/Extensions",
                    "Core/Navigation", "Core/Notification", "Core/UI",
                    "Core/Audio/AVAudioEngineAdapter.swift", "Core/Audio/AudioRecorder.swift", "Core/Audio/AudioRecorderEvent.swift",
                    "Core/Speech/AVSpeechSynthesizerAdapter.swift", "Core/Speech/SpeechAnalyzerAdapter.swift",
                    "Core/Speech/SpeechRecognizer.swift", "Core/Speech/SpeechSynthesizer.swift", "Core/Speech/Supertonic",
                    "Core/Speech/SupertonicAdapter.swift",
                    "Core/AI/CareCallGenerables.swift", "Core/AI/CoreAICareCallAdapter.swift", "Core/AI/GeneratedPresence.swift",
                    "Core/AI/LanguageModelProvider.swift", "Core/AI/PromptTemplate.swift",
                    "Services/Auth", "Services/Exercise", "Services/Hospital", "Services/Intake", "Services/Notification",
                    "Services/Pain", "Services/Records", "Services/User",
                    "Services/Symptom/CareCall/CareCallService.swift",
                ],
                sources: [
                    "Core/AI/CareCallAI.swift", "Core/AI/CareCallStep.swift", "Core/AI/MentionPresence.swift",
                    "Services/Symptom/CareCall/BodyPartDictionary.swift",
                    "Services/Symptom/CareCall/CareCallConfig.swift", "Services/Symptom/CareCall/CareCallConfigError.swift",
                    "Services/Symptom/CareCall/InterviewEngine.swift", "Services/Symptom/CareCall/InterviewPhase.swift",
                    "Services/Symptom/CareCall/KeywordMatcher.swift", "Services/Symptom/CareCall/Ledger.swift",
                    "Services/Symptom/CareCall/NumberParser.swift", "Services/Symptom/CareCall/PlannedQuestion.swift",
                    "Services/Symptom/CareCall/SlotPlanner.swift", "Services/Symptom/CareCall/SymptomRecordConverter.swift",
                    // 케어콜 화면 ViewModel (CareCalling으로 가짜 서비스를 넣어 검증)
                    "Features/Symptom/Presentation", "Features/Symptom/ViewModels",
                    "Services/Symptom/CareCall/CareCalling.swift", "Services/Symptom/CareCall/CareCallActivity.swift",
                    "Services/Symptom/CareCall/CareCallOutcome.swift", "Services/Symptom/CareCall/CareCallTurn.swift",
                    "Services/Symptom/CareCall/CareCallServiceError.swift", "Core/Audio/AudioRecorderError.swift",
                    "Core/AI/LanguageModelError.swift", "Core/Speech/SpeechRecognizerError.swift",
                    "Data/Repositories/Protocols/Repository.swift",
                    "Data/Repositories/Protocols/RecordRepository.swift", "Data/Repositories/Protocols/SymptomRepository.swift",
                    "Data/Repositories/Protocols/PendingCareCallRepository.swift",
                ],
                swiftSettings: [.enableUpcomingFeature("BareSlashRegexLiterals")]),
        .testTarget(name: "CareCallEngineTests", dependencies: ["ToDocCareCall", "ToDocDomain"], path: "Tests/CareCallEngineTests",
                    swiftSettings: [.enableUpcomingFeature("BareSlashRegexLiterals")]),
    ],
    swiftLanguageModes: [.v5]
)
