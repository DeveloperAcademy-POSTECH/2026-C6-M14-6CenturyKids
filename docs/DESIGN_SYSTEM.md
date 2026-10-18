# ToDoc 화면과 디자인 시스템

2026-10-18 기준. 기존 공통 UI를 확장해 인증·온보딩·알림·진료 전 기록·케어콜·통증·설정의 활성 View 72개 파일을 점검한다. 홈 View·ViewModel은 #107 병합 후 별도 PR로 진행하므로 이번 변경에서 제외했다. 기록 대시보드 6개 파일도 디자인 수정 중이므로 제외했다. 식사·운동, 복용약 관리, 의료진 iPad도 기존 보류 범위를 유지한다.

## 변경할 위치

화면은 `ToDoc/Core/UI`의 공통 정의를 사용한다. 서로 다른 Figma 규격은 이름 있는 변형으로 보존한다. 동일한 색이나 숫자가 보인다는 이유만으로 의미가 다른 토큰을 합치지 않는다.

| 변경할 디자인 | 수정할 정의 | 사용 방법 |
|---|---|---|
| 기본 Heading/Label/Caption | `DesignSystem/AppTypography+Style.swift` | `.appTextStyle(.heading)` 등 |
| 본문·질문·숫자·화면별 글꼴 | `AppTypography+Token.swift`와 `+Forms`, `+PatientScreens`, `+Conversation`, `+Pain` | `.appFont(.body)`, `.appFont(.question)` 등 |
| 공통 색상 | `AppColors.swift`, `AppColors+Text.swift`, `AppColors+Surface.swift` | `AppColors.surface`, `AppColors.Text.placeholder` 등 |
| 화면군별 의미 색상 | `AppColors+Forms/PatientScreens/Conversation/Pain.swift` | `AppColors.Settings.*`, `AppColors.CareCall.*` 등 |
| 카드 배경·모서리·테두리 | `AppSurfaceToken.swift`와 변형 파일 | `.appSurface(.previsitCard(selected: true))` |
| 공통 간격·규격 | `AppSpacing+Content.swift`, `AppMetrics+*.swift` | `AppSpacing.section`, `AppMetrics.Conversation.inputHeight` 등 |
| 기본 CTA | `AppButtonStyle.swift`, `AppMetrics+PillButton.swift` | 기존 `.buttonStyle(AppButtonStyle(...))` 사용 |
| 반복 입력·진행률·모드 전환 | `Components/AppAnswerEditor`, `AppProgressTrack`, `AppCircleControl` | Binding과 콜백 전달 |
| 대화 본문과 하단 조작 배치 | `Components/AppConversationLayout.swift` | 일반 크기에서는 하단 고정, 접근성 글자 크기에서는 전체 스크롤 |

기본 CTA의 높이 80, 반경 40, 외곽선 2와 기존 Heading의 130% 행간은 유지했다. 새 `appFont`는 Auto 행간용이며 기본 스타일을 대체하지 않는다. Pretendard 등록·크기 확대·fallback은 공통 경로를 사용한다. 토큰에 자간이 없으면 호출한 화면의 기존 자간을 덮지 않는다.

## 재사용 예시

```swift
VStack(spacing: AppSpacing.section) {
    Text("얼마나 지속 되었나요?").appFont(.question)
    AppProgressTrack(value: progress)
    AppAnswerEditor(
        text: $answer,
        accessibilityLabel: "지속 시간 답변",
        accessibilityIdentifier: "carecall.duration.answer",
        isEnabled: !isSaving
    )
}
```

`AppAnswerEditor`는 입력 값을 소유하지 않는다. 호출한 화면이 Binding을 유지하므로 화면이나 입력 모드를 전환해도 기존 초안을 전달할 수 있다. `AppCircleControl`은 콜백이 없으면 비활성이다. `AppProgressTrack`은 0...1 범위를 사용하고 nil/비유한 값은 “확인 중”으로 읽는다. 화면과 접근성 값 모두 같은 정규화 값을 사용한다.

`AppSurfaceToken`은 배경·모서리·테두리만 담당한다. padding, 입력 상태, 키보드, 화면 이동은 호출 화면이 담당한다. 이 구분을 유지하면 카드 색상 변경 때문에 주변 레이아웃이나 데이터 흐름을 다시 작성할 필요가 없다.

## 의도적으로 구분한 변형

- 인증의 입력 필드, 설정의 그룹 행, 대화의 큰 입력 상자는 규격과 동작이 달라 별도 이름으로 정의했다. 기본 색상과 글꼴 렌더러를 공유한다.
- 케어콜의 `CareCallManualPendingButton`은 Figma의 미답변 전용 표시다. 공통 CTA 크기를 사용하면서 기존 regular 글꼴·solid 테두리·native plain 비활성 표시를 보존한다. 다른 화면으로 확장할 때 실제 공통 요구가 확인되면 Core/UI로 옮긴다.
- 통증 게이지·몸 그림의 좌표, 숫자 휠의 고정 숫자 크기는 그림과 맞물린 기하이므로 일반 간격 토큰으로 일괄 치환하지 않는다. 숫자 의미(0, 미선택, 10+)도 바꾸지 않는다.
- SF Symbol의 `.font(.system(...))`는 아이콘 크기용이다. 알림 설정의 native Form 및 기존 native 대화 요약/편집 서체는 명시한 변형을 유지한다.
- 브랜드 색·입력 focus 색·설정 보조문구 색은 현재 원본 디자인의 구분을 유지했다. 접근성 대비를 바꾸려면 해당 의미 토큰을 조정하고 해당 화면군을 다시 확인한다.

## 새 화면이나 디자인 변경 검증

1. 기존 토큰과 컴포넌트에 같은 역할이 있는지 확인한다. 있으면 재사용하고, 반복되는 새로운 역할은 의미 있는 이름으로 Core/UI에 추가한다.
2. 기능 View 안에 `Color(...)`, 직접 `UIFont`, 별도 Pretendard 렌더러를 추가하지 않는다. 검사를 통과시키기 위한 예외만 늘리지 않는다.
3. `Features/Patient/Previews/DesignSystemAuditPreview.swift`에서 일반 화면과 320pt·접근성 큰 글자를 확인한다. `AppComponentsPreview.swift`는 공통 입력/진행률/비활성 표시를 확인한다.
4. 입력 전·선택·실패·비활성 상태 및 화면 이동을 확인한다. 변경 전후 화면을 비교하고, 실제 UI 빌드와 관련 회귀 검사를 실행한다.

```sh
python3 Scripts/check_design_system.py
swift test
```

검사 스크립트는 활성 Views의 직접 색상 생성·개별 글꼴 렌더러 재도입을 찾으며 파일별 JSON을 `--output report.json`으로 저장할 수 있다. 정적 검사는 시각 일치·모든 조작·VoiceOver 실제 발화를 증명하지 않는다. 컴포넌트 수정 때는 Preview와 Simulator 확인을 함께 한다.

## 이번 PR의 범위와 확인 방법

- 최신 Figma의 진료 전 기록, 알림, 케어콜 음성/수동 입력, 복용 후 통증 기록, 마이페이지 화면을 포함한다. 실제 기능 연결에 필요한 표시 값과 콜백을 제공하며 예시 데이터는 DEBUG Preview에 있다.
- 홈 소스는 기준 PR #107과 동일하다. 진료 전 기록 Preview는 안내부터 시작하고, 닫으면 개발용 재시작 버튼으로 돌아온다. 제품 홈에서의 진입 연결은 후속 Home PR에서 다룬다.
- `Scripts/check_design_system.py`는 활성 72개와 보류 7개(홈 1개·기록 6개)를 구분해 검사한다. 보류 파일의 남은 중복 스타일을 이번에 해결했다고 표시하지 않는다.
- 인증 ViewModel·가입 순서·Domain·Repository·기본 앱 진입·프로젝트·Package는 #107 그대로다. 가입 Preview와 암종 변경은 별도 후속 PR이다.
- 공통화 전 로컬 작업에서는 일반 75상태·큰 글자 9상태를 비교해 스타일과 케어콜 접근성 배치를 확인했다. 이는 과거 검증이며, 이번 PR의 새 테스트·빌드 결과와 대표 화면은 PR 본문 및 `docs/pr-assets/ui-design-system/`에 별도로 기록한다.

화면을 한 번에 보려면 `Features/Patient/Previews/DesignSystemAuditPreview.swift`의 “전체 화면 · 디자인 시스템 검증”을 연다. 케어콜 흐름은 `Features/Symptom/Previews/CareCallConversationPreview.swift`에서 음성↔수동 전환과 횟수·시간 입력을 확인한다. Preview의 로컬 완료 표시는 실제 서버 저장·음성 엔진 동작을 의미하지 않는다.
