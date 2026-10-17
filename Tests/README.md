# ToDoc 자동 테스트 안내

이 폴더는 앱 코드를 점검하는 **자동 점검표**입니다. 앱과 함께 버전 관리하며, 관련 기능 코드와 같은 PR에 포함해서 공유할 수 있습니다. 별도로 설치해야 하는 테스트 앱이나 실제 환자 자료가 아닙니다.

## 앱 코드·테스트·Preview의 차이

| 위치 | 역할 | 어떻게 쓰나요? |
|---|---|---|
| `ToDoc/` | 실제 앱 소스 | `ToDoc.xcodeproj`로 앱을 빌드합니다. |
| `Tests/` | 실제 Model·ViewModel·엔진에 입력을 주고 결과를 확인하는 코드 | 저장소 루트에서 `swift test`로 실행합니다. |
| `Package.swift` | 테스트가 어떤 앱 소스와 검사 파일을 사용할지 정하는 목록 | Swift Package Manager가 읽습니다. 앱 배포 설정은 Xcode 프로젝트가 관리합니다. |
| `ToDoc/Features/.../Previews/` | 화면을 눈으로 확인하는 SwiftUI 미리보기 | Xcode Canvas에서 엽니다. 자동 테스트 통과와는 다른 확인입니다. |

현재 Xcode 앱 타깃의 동기화 소스 폴더는 `ToDoc`입니다. 루트의 `Tests`는 앱 타깃에 등록되어 있지 않아 앱에 들어가지 않습니다. 이 테스트들은 별도 Swift Package 타깃이므로 `ToDoc.xcodeproj`의 Run 또는 Cmd+U만으로 아래 검사가 전부 실행되는 구성은 아닙니다.

## 실행 방법

터미널의 현재 위치를 **`Package.swift`가 있는 저장소 루트**로 옮긴 뒤 실행합니다.

```sh
# 전체 테스트. 이전에 설정한 일부 실행용 환경변수도 해제합니다.
env -u TODOC_TEST_SCOPE swift test
```

빠르게 특정 부분을 확인할 수도 있습니다.

```sh
# 인증 ViewModel + 인증 화면 상태
TODOC_TEST_SCOPE=auth swift test

# 인증 + 케어콜 + 화면 상태 (DomainTests 제외)
TODOC_TEST_SCOPE=features swift test

# 전체 타깃을 빌드한 뒤 DomainTests 검사만 실행
# --filter는 실행 대상을 좁히는 옵션이며 다른 타깃의 컴파일 생략 옵션은 아닙니다.
env -u TODOC_TEST_SCOPE swift test --filter DomainTests
```

검증한 도구 환경은 Xcode 27.0 / Apple Swift 6.4입니다. 다른 버전에서의 호환성은 별도 확인이 필요합니다. `swift --version`, `xcodebuild -version`으로 확인할 수 있습니다. 테스트 패키지는 macOS 14 이상을 선언하며, 이것은 Swift 컴파일러의 최소 버전 보장을 뜻하지 않습니다.

기본 빌드 결과는 `.build/`에 생기고 Git에서 제외됩니다. `--scratch-path <임시폴더>`로 결과 위치를 바꿀 수도 있습니다. 테스트 소스 자체는 `Tests/`에 그대로 남습니다.

## 무엇을 확인하나요?

2026-10-17 전체 실행 결과는 **256개 통과, 실패 0개**입니다.

| 묶음 | 개수 | 대표 검사 |
|---|---:|---|
| DomainTests | 54 | 이름·생일·통증 범위, 값 수정 실패 시 원본 보존, 환자·의사·병원 ID 관계, 증상 원문 보존 |
| AuthViewModelTests | 35 | 로그인·가입·복구·온보딩, 미연결 오류, 취소·재시도, 잘못된 사용자 ID 차단 |
| AuthScreenTests | 2 | 가입 생일 표시 |
| SymptomScreenTests | 2 | 있음 증상만 표시하고 원본 답변 유지 |
| CareCallEngineTests | 163 | 케어콜 질문 진행·응답 해석·저장 상태 |

XCTest와 Swift Testing을 함께 사용하므로 실행 결과가 여러 묶음으로 출력됩니다. 어떤 묶음에 `0 tests`가 보여도 그것만으로 전체가 실행되지 않았다는 뜻은 아닙니다. 전체 명령의 종료 상태와 각 타깃 결과를 함께 확인합니다. Swift Testing의 매개변수별 사례 수와 `Test run with 163 tests`의 테스트 수는 구별합니다.

식사·운동 Model의 기존 검사는 유지합니다. 해당 검사가 존재한다는 이유로 앱의 제외된 식사·운동 화면이 다시 활성화되지는 않습니다.

## 기본 앱 진입 회귀는 어떻게 확인했나요?

이 Swift 패키지는 SwiftUI 앱의 `ToDocApp/ContentView`를 빌드하지 않습니다. 따라서 256개 단위 테스트만 통과해도 앱 입구가 막히는 문제는 놓칠 수 있습니다. 이번에는 iOS Simulator에서 Debug 기본 실행의 홈 표시, 홈→케어콜→복귀, 기록 화면 이동, Release에 개발 인자를 전달해도 홈 유지, Debug의 별도 `--auth-flow` 진입을 추가로 확인했습니다. 앱 빌드와 실제 실행 결과를 단위 테스트 결과와 구분합니다.

## 가짜 Repository는 왜 있나요?

`AuthViewModelTests/AuthRepositoryDoubles.swift`는 서버 역할을 대신하는 테스트 전용 객체입니다. 예를 들어 “계정은 맞지만 환자 프로필이 없다”, “저장 요청이 실패한다”, “취소한 뒤 응답이 늦게 돌아온다”라는 상황을 컴퓨터 안에서 재현합니다.

검사 대상인 **ViewModel은 실제 앱 코드**를 그대로 사용합니다. 바깥쪽 Repository만 테스트 전용 객체로 바꿔서 ViewModel의 판단을 확인합니다. 이 객체는 `Tests` 타깃 안에만 있고 제품 앱의 DI에 연결되지 않습니다. 테스트의 예시 이메일·비밀번호는 실제 계정 발급이나 메일 발송에 쓰지 않습니다.

단위 테스트 통과는 실제 Supabase DB 저장·메일 링크·권한 설정까지 확인했다는 뜻이 아닙니다. 팀원의 실제 Repository, 약관과 URL 설정을 연결한 뒤 테스트 환경에서 통합 검증해야 합니다. DomainValidationTests의 이메일 사례는 기존 Domain 검증 함수만 검사하며 인증 화면이나 서버의 이메일 검증을 대신하지 않습니다.

## 팀에 공유할 때

- 관련 앱 소스, 관련 `Tests/...` 소스, 실행에 필요한 `Package.swift` 변경을 같은 PR에 포함합니다. 테스트 파일만 따로 보내면 그 테스트가 참조하는 최신 앱 타입이 없어 실행되지 않을 수 있습니다.
- 이번 테스트 설정은 인증·케어콜이 공유하는 소스를 `ToDocFeatures`로 묶습니다. 이전 `Package.swift`와 새 테스트만 섞으면 import 오류가 날 수 있으므로 같은 브랜치의 파일 조합으로 확인합니다.
- 이 README도 함께 공유하면 실행 명령과 검증 범위를 전달할 수 있습니다. 개인 절대 경로나 로컬 전용 도우미 없이 실행 가능합니다.
- `.build/`, DerivedData, 실행 로그, 개인 작업 기록과 백업은 실행에 필요하지 않습니다. 소스 PR에 포함하지 않습니다.
- 화면 리뷰용 이미지는 이번 요청에 따라 `docs/pr-assets/auth-flow/`에 별도로 포함합니다. 테스트 실행에는 필요하지 않습니다.
- 테스트 파일의 변경은 앱 기능 변경과 마찬가지로 리뷰합니다. 실패를 숨기려고 테스트를 지우거나 제외하지 않습니다.

공유 여부와 게시 시점은 팀 작업 방식에 맞춰 정하면 됩니다. 이 안내 파일을 작성하는 것 자체가 GitHub 게시나 팀원 전송을 의미하지는 않습니다.
