# 인증 화면 캡처

2026-10-17, iPhone 18 Pro / iOS 27 Simulator. 앱의 실제 SwiftUI View를 실행해 캡처했습니다. `preview@example.com`, 홍길동, 생일/진단은 개발용 예시이며 실제 사용자의 자료가 아닙니다.

`AuthScreenCaptureView`는 DEBUG에만 포함됩니다. Xcode Scheme → Run → Arguments에 `--auth-preview login`처럼 두 인자를 넣으면 해당 화면을 열 수 있습니다. Repository는 전부 nil이므로 서버 인증/저장을 하지 않습니다. 인자를 지우면 제품 진입점으로 실행합니다. Release에는 이 도구가 없습니다.

| 인자 | 이미지 | 확인 내용 |
|---|---|---|
| onboarding | [시작](onboarding.jpg) | C6 임시 문구 제거·캐릭터 중앙·시작/로그인 |
| intro | [소개](intro.jpg) | 중앙 페이지 표시·다음·건너뛰기 |
| login | [로그인](login.jpg) | 입력·자동 로그인 선택·가입/찾기 링크 |
| signup | [역할 선택](signup.jpg) | 환자 가입 진입 |
| terms | [약관](terms.jpg) | 실제 약관 본문 미정 안내 |
| patient | [개인 정보](patient.jpg) | 생일 한글 표시·성별 |
| review | [가입 검토](review.jpg) | 저장 전 입력 확인 |
| completion | [가입 완료 예시](completion.jpg) | 화면 표시 예시이며 실제 서버 가입 성공 증거가 아님 |
| reset | [비밀번호 찾기](reset.jpg) | 메일 입력 |
| recovery | [새 비밀번호 예시](recovery.jpg) | 검증 후 표시할 화면 예시, 저장 비활성 |

`--auth-preview-large-text`를 추가하면 폭320pt/접근성 글자 크기로 확인할 수 있습니다. 이 설정도 개발 전용입니다. 추가 캡처: [실제 미연결 안내와 키보드](login-unconnected.jpg), [큰 글자 상단](login-large-top.jpg), [큰 글자 하단 스크롤](login-large-bottom.jpg). 실제 조작에서 시작→소개4페이지→가입, 진입 위치별 뒤로 복귀, 이메일 오류, 자동 로그인 체크와 미연결 안내를 확인했습니다.

기존 원본 에셋·공통 UI 규격을 사용했습니다. 최신 Figma 조회는 권한 오류로 확인하지 못하여 최신 Figma와 완전히 일치한다고 주장하지 않습니다.
