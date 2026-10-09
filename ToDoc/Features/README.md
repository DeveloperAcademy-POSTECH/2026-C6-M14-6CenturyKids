# 환자용 iPhone 화면 구조

기능별 화면과 ViewModel은 `Features`에 둡니다. 현재는 각 기능의 기본 View와 Preview를 준비한 화면 뼈대입니다.

| 폴더 | 기본 화면 | 역할 |
| --- | --- | --- |
| Onboarding | OnboardingView | 앱 소개와 시작 안내 |
| Auth | LoginView, SignupView | 환자 로그인과 회원가입 |
| Home | HomeView | 오늘의 기록과 담당의 메시지 진입 |
| Symptom | SymptomRecordView | 하루 안부와 증상 기록 |
| Pain | PainRecordView | 대표통증의 복용 전후 기록 |
| Intake | IntakeRecordView | 끼니별 식사량과 선택적인 사진 기록 |
| Exercise | ExerciseRecordView | 의료진이 정한 운동 목표와 실천 기록 |
| Records | RecordsView | 통증·증상·식사·운동 기록 조회 |
| Settings | SettingsView | 개인·건강 정보와 의료진 연결 관리 |
| Notification | NotificationView | 담당의 메시지와 기록 요청 알림 |

## 이번 화면 뼈대의 범위

- 앱의 `ContentView`에서 홈·기록확인·설정 3개 탭을 표시합니다.
- 각 탭은 별도의 `NavigationStack` 안에서 기본 화면을 표시합니다.
- 나머지 기본 화면은 각 파일의 `#Preview`로 확인할 수 있습니다. 전체 화면 이동은 기능별 작업에서 연결합니다.
- 기본 화면은 제목과 기능 설명만 표시합니다. 상세 디자인·그래프·입력·저장은 아직 구현하지 않았습니다.

## 기능별 작업 기준

입력 단계와 화면 상태는 각 기능을 구현하면서 나눕니다. 선택 전후·일/주/월·로딩·완료 상태마다 별도 페이지 파일을 미리 만들지 않습니다.

ViewModel은 입력 상태와 서비스 호출이 필요할 때 추가하며 `View → ViewModel → Service` 흐름을 따릅니다. Features에서 Repository를 직접 호출하지 않습니다. Model·Service·Repository 계약은 팀 클래스 다이어그램을 준수합니다.

디자인 토큰과 공통 컴포넌트, 인증·음성·저장 기능, 의료진용 iPad 화면은 후속 작업에서 진행합니다.
