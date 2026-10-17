# 인증 View·ViewModel 연결 안내

2026-10-17 기준. 최신 develop의 Model/Repository 계약을 유지하고 인증 화면과 ViewModel을 연결했습니다. 인증 Service는 제거했습니다. 나머지 Service는 각 기능 담당자의 전환 범위이며 이 PR에서 일괄 삭제하지 않습니다.

## 앱을 실행하면 어디로 가나요?

**기본 실행은 기존 홈입니다. Debug와 Release 모두 홈·기록·설정 화면을 확인할 수 있습니다.** 아직 실제 PatientRepository가 없는 상태에서 인증을 앱 전체의 필수 입구로 만들면 팀원의 화면 작업까지 막히므로, 인증 흐름은 별도 개발 경로로 분리했습니다.

| 실행 방법 | 처음 열리는 화면 | 인증 ViewModel의 세션 복원/링크 처리 |
|---|---|---|
| 인자 없이 실행 (Debug/Release) | 기존 홈 (`ContentView → PatientFlowView`) | 실행하지 않음 |
| Debug + `--auth-flow` | 온보딩·인증 (`AuthDevelopmentRootView`) | 기존 실제 DI로 실행 |
| Debug + `--auth-preview login` 등 | 지정한 화면 예시 | 서버 연결 없는 캡처 전용 |
| Release + 개발 인자 | 기존 홈 | 개발 경로는 컴파일에서 제외 |

Xcode에서 **Product → Scheme → Edit Scheme → Run → Arguments → Arguments Passed On Launch**에 `--auth-flow` 한 항목을 추가하고 체크한 뒤 실행하세요. 기본 홈으로 돌아가려면 그 체크를 끄고 앱을 다시 실행합니다. 공용 Scheme/프로젝트 파일은 바꾸지 않았습니다. 캡처 인자와 함께 있으면 `--auth-preview`를 우선합니다.

기본 홈을 열었다는 이유로 로그인 성공 상태나 임의 환자 정보를 만들지 않습니다. 홈/기록 등에 있는 기존 데이터 미연결 안내는 그대로입니다. 실제 인증 세션이 필요한 기능까지 연결됐다는 뜻은 아닙니다. 자동 로그인 선택·복구 링크 처리 검증은 `--auth-flow` 경로에서 진행합니다. 기본 홈 실행은 인증 ViewModel을 생성하거나 그 ViewModel의 로그아웃/세션 복원을 요청하지 않습니다.

## 누가 무엇을 맡나요?

사용자는 모든 View·공통 UI와 온보딩/인증 ViewModel을 담당합니다. 비인증 ViewModel, Model, DTO, DB 및 Repository 구현체는 해당 팀원이 담당합니다. 이 문서는 구현 연결 지점이며 담당자 수락이나 일정 확정을 뜻하지 않습니다.

## 코드가 움직이는 순서

`View(버튼/입력) → ViewModel(검증·진행·오류) → Repository(서버/DB) → ViewModel 상태 → View`

View는 저장이 끝났는지 직접 판단하지 않습니다. 예를 들어 로그인 버튼을 누르면 LoginViewModel이 이메일을 검사하고 AuthRepository로 인증한 뒤 UserRepository와 PatientRepository에서 같은 UUID의 프로필을 확인합니다. 두 정보가 모두 맞을 때만 **인증 개발 경로 안에서** 환자 화면으로 전환합니다. 기본 홈 경로와 이 인증 판정은 서로 독립적입니다.

## 현재 연결과 남은 연결

| 연결 | 상태 | 연결 후 확인할 사항 |
|---|---|---|
| AuthRepository | 기존 SupabaseAuthRepository 연결 | 테스트 서버의 로그인/메일 정책 |
| UserRepository | 최신 SupabaseUserRepository 기본 연결 | users 테이블 및 RLS/날짜 매핑 |
| PatientRepository | 프로토콜 있음, 실제 구현체 미주입 | findById/save, User와 동일 UUID, 저장 후 조회 |
| DoctorRepository | 프로토콜 있음, 실제 구현체 미주입 | 6자리 의사 코드 확인. 미연결이면 건너뛰기 가능 |
| HospitalRepository | 최신 develop의 SupabaseHospitalRepository 존재, 인증 DI에는 미주입 | DoctorRepository와 함께 소속 병원 확인을 연결 |
| SignupConsentRepository | 새 계약만 준비 | userID+version 재시도 중복 방지, 서버 저장 성공 후 반환 |
| AuthCallbackRepository | 새 계약만 준비 | SDK/서버가 확인한 password recovery 링크만 세션으로 교환 |
| 약관 본문·버전 / redirect URL | 미정 | 확정 후 AuthConfiguration으로 주입 |

`DependencyContainer.makeAuthFlow(...)`가 실제 객체를 넣는 한 곳입니다. 구현체를 넘기면 View/VM을 다시 작성할 필요가 없습니다. 기존 Auth/User와 같은 SupabaseClient를 사용하세요. nil은 미연결을 뜻하며 성공하는 가짜 구현으로 대체하지 않습니다.

```swift
// 실제 구현체가 준비된 뒤 앱 조립 지점에서 전달하는 형태입니다.
let flow = container.makeAuthFlow(
    configuration: AuthConfiguration(terms: approvedTerms,
                                     termsVersion: approvedVersion,
                                     redirectURL: approvedRedirectURL),
    patients: patientRepository,
    doctors: doctorRepository,
    hospitals: hospitalRepository,
    consents: signupConsentRepository,
    callbacks: authCallbackRepository
)
```

URL이 정해지면 앱의 URL scheme 또는 Universal Links 설정, Supabase 허용 redirect 목록, 메일 템플릿, 실제 기기 앱 복귀를 함께 연결해야 합니다. 지금은 임의 주소를 등록하지 않았습니다. URL의 고정 주소만 일치한다고 복구를 허용하면 안 됩니다. CallbackRepository는 일반 가입/로그인 링크와 복구 링크를 구분하고 만료/재사용/변조된 토큰을 서버 검증으로 거절해야 합니다.

## 기능별 동작

- 온보딩: 시작 → 소개 4페이지 → 가입. 건너뛰기는 가입으로, 로그인 링크는 로그인으로 이동합니다. 직접 가입 뒤로는 온보딩, 로그인에서 가입 뒤로는 로그인입니다.
- 로그인: 입력 검사, 인증, 사용자/환자 프로필 일치 확인. 실패/취소한 요청은 홈을 열지 않습니다. 늦게 끝난 요청을 정리하기 전에는 다른 인증 요청을 시작하지 않습니다.
- 자동 로그인: 기본 해제. 체크한 로그인에서 인증과 프로필 확인이 모두 성공해야 다음 인증 개발 경로(`--auth-flow`) 실행의 복원을 허용합니다. 해제한 로그인은 현재 실행 동안 이용하고 다음 인증 개발 경로(`--auth-flow`) 실행에서 SDK 세션을 정리합니다. 설정에는 선택 bool만 저장하며 이메일·비밀번호·토큰을 추가 저장하지 않습니다. 토큰 보관은 기존 SDK가 담당합니다. 가입/복구용 임시 세션은 복원하지 않습니다.
- 가입: 환자 역할 → 이름/이메일/비밀번호/확인 → 실제 약관 동의 → 선택적 의사 연결 → 생일/성별/암종/병기 → 검토 → 계정 생성/이메일 확인 → 사용자/동의/환자 저장 → 재조회 → 로그아웃 → 완료 → 로그인입니다.
- 가입 재시도: 같은 실행에서 성공한 저장 단계를 기억합니다. 네트워크 오류 뒤 서버 계정 생성 여부가 불확실하면 자동으로 signUp을 반복하지 않습니다. 기존 정보로 이어가거나, 안내 확인 후 처음부터 다시 작성할 수 있습니다. 재작성은 서버 계정을 삭제하지 않습니다. 앱 종료를 넘는 미완료 가입 복구는 서버 가입 상태 계약이 추가로 필요합니다.
- 비밀번호 찾기: 메일 요청 성공과 비밀번호 변경 성공을 구분합니다. 주소/링크 처리 미연결이면 메일 전송 성공을 표시하지 않습니다.
- 비밀번호 재설정: 검증된 recovery 링크 → 새 비밀번호/확인 → 저장 → 복구 세션 정리 → 새 비밀번호로 로그인. 변경 뒤 로그아웃만 실패하면 비밀번호를 다시 변경하지 않고 정리만 재시도합니다.

‘기타 암종/모름·직접 입력 병기’는 기존 DB Model이 표현하지 못하여 임의 값으로 저장하지 않습니다. 해당 계약 확정이 필요합니다. Apple 로그인/의사 iPad 가입/회원탈퇴는 이번 구현 범위에 추가하지 않았습니다.

## 확인 방법

저장소 루트에서 `env -u TODOC_TEST_SCOPE swift test`를 실행합니다. 상세는 [테스트 안내](../Tests/README.md)입니다. 자동 테스트는 실제 ViewModel에 테스트 전용 Repository를 넣어 오류·취소·저장 순서·자동 로그인 정책을 확인합니다. 테스트 서버의 실제 인증 성공을 대신하지 않습니다.

[화면 이미지와 재현 방법](pr-assets/auth-flow/README.md)도 포함했습니다. Xcode Canvas는 현재 ONNX 조합의 JIT 문제 때문에 로컬 Legacy Previews를 사용합니다. 프로젝트의 ONNX 버전은 변경하지 않았습니다.

## 최신 develop 충돌 처리

`8ce739d`를 병합했습니다. 새 HospitalRepository API와 SupabaseHospitalRepository 구현은 develop 내용을 유지합니다. AuthenticationService 수정/삭제 충돌은 이 PR의 Service 제거 결정을 유지했습니다. develop의 해당 수정은 옛 메서드 호출을 `requestPasswordChangeVerification()`으로 바꾸는 내용입니다. 새 비밀번호 찾기 ViewModel은 이미 `sendPasswordResetEmail(to:redirectTo:)`를 직접 사용하므로 삭제한 Service를 복원하거나 서로 다른 비밀번호 유스케이스를 섞지 않았습니다.

## 인증을 기본 진입점으로 전환하기 전

지금 기본 홈 진입은 팀 개발 환경을 유지하기 위한 단계입니다. 출시용 인증 적용이 끝났다는 뜻이 아닙니다. 실제 Repository와 약관/복귀 URL을 연결하고, 아래 통합 확인 후 앱의 기본 진입을 인증으로 전환하는 별도 변경이 필요합니다. 기본 화면이 저장소 nil 여부에 따라 자동으로 바뀌지는 않습니다.

## 아직 필요한 통합 확인

실제 Patient/Consent/Callback 구현체, 약관/URL 설정을 주입한 다음 테스트 서버와 실기기에서 가입→메일 확인→DB 저장→로그인→자동 로그인→복구 메일→비밀번호 변경을 확인해야 합니다. 현재 View/VM의 구현·자동 테스트·시뮬레이터 화면 검증과 이 서버 통합 검증을 구분합니다.

기존 계정 로그인에는 같은 인증 UUID의 users·patients 행이 있어야 합니다. 회원가입에는 이 행의 저장뿐 아니라 동의 저장·약관 버전·인증 메일 복귀 설정도 필요합니다. 이는 화면 진입 복원과 별개의 팀 연결 작업입니다.
