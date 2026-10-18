# 암종 기타 입력·병기 모름 계약 변경

2026-10-18 사용자 요청 반영. `feat/signup-preview-diagnosis`의 View·Domain·가입 VM·PatientDTO 변경이다. #107 → #121(화면·디자인시스템) → 가입 Preview·암종 Draft 순서로 쌓는다. **실제 Supabase 스키마에는 아직 적용하지 않았다. 아래 서버 선행 작업과 최신 develop 연결을 완료하기 전에는 병합·배포 준비 완료로 전환하지 않는다.**

## 동작

- 암종: 기존 15종 + 기타 직접 입력. 기타를 선택하면 이름을 입력해야 다음 단계/저장을 진행할 수 있다.
- 자유 텍스트의 앞뒤 공백만 제거하고 내부 띄어쓰기·원문을 보존한다.
- 병기: 0기~4기 + **모르겠어요**. ‘다른 표현으로 들었어요’와 병기 자유 입력은 제거했다.
- ‘모르겠어요’는 미입력과 다르다. 사용자가 선택한 값은 `unknown`, 선택하지 않은 입력은 검증 오류다.
- 회원가입과 마이페이지 암종/병기 수정에 동일한 선택지를 적용했다. 마이페이지 저장은 현재 화면 상태/외부 콜백 계약이며 서버 VM 연결은 별도다.

## 저장 필드

| 위치 | 필드/값 | 의미 |
|---|---|---|
| CarcinomaType | `other` 신규 case | 암종 기타 |
| CarcinomaStage | `unknown` 신규 case | 병기를 모르겠어요 |
| CarcinomaDetail | `otherName: String?` | 기타일 때만 입력한 실제 이름 |
| PatientDTO | `carcinomaOtherName: String?` | DTO 필드 |
| patients | `carcinoma_other_name text NULL` | 새 DB 컬럼 |
| patients.carcinoma_type | 기존 값 또는 `other` | 기존 15개 raw value 유지 |
| patients.carcinoma_stage | 기존 값 또는 `unknown` | 기존 stage0~stage4 유지 |

기타 예시:

```json
{
  "carcinoma_type": "other",
  "carcinoma_stage": "unknown",
  "carcinoma_other_name": "연부조직 육종"
}
```

일반 암종으로 변경할 때:

```json
{
  "carcinoma_type": "lung",
  "carcinoma_stage": "stage2",
  "carcinoma_other_name": null
}
```

`null`을 명시적으로 전송한다. 키를 생략하면 upsert에서 이전 기타 이름이 남을 수 있다. 기타인데 이름이 없거나 공백뿐인 DTO는 읽기/쓰기 모두 오류로 처리한다. 기존 일반 암종 데이터에 새 컬럼이 없어도 디코딩할 수 있다.

## 서버 선행 작업 — 담당자 적용 필요

1. `public.patients.carcinoma_other_name` nullable text 컬럼 추가.
2. `carcinoma_type` 허용값에 `other`, `carcinoma_stage` 허용값에 `unknown` 추가. 실제 DB가 PostgreSQL enum인지 text+CHECK인지 확인하고 해당 스키마 방식으로 변경한다. 저장소에는 실제 enum 타입명/CHECK 정의가 없어 이름을 추측한 DDL은 작성하지 않았다.
3. 기타에는 빈 문자열을 허용하지 않고, 일반 암종에서는 기타 이름을 NULL로 저장하는 규칙을 서버에도 적용한다. 기존 데이터 점검 후 제약을 추가한다.
4. 환자 응답과 명시적인 select 목록에 새 컬럼을 포함하고, 기존 읽기/쓰기 권한으로 왕복 검증한다.
5. 서버 스키마를 먼저 배포한 뒤 이 변경을 실제 저장 경로에 연결한다. **새 DTO는 일반 암종에도 새 컬럼을 NULL로 보내므로 컬럼이 없는 서버에 먼저 연결하면 기존 가입/저장도 실패할 수 있다.**
6. 이전 앱은 other/unknown raw value를 인식하지 못한다. 구버전 클라이언트가 같은 환자를 읽을 때의 배포·호환 정책을 함께 확인한다.

컬럼 추가 SQL 예시(이번 작업에서 실행하지 않음):

```sql
ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS carcinoma_other_name text;
```

이 한 문장은 enum/CHECK 허용값 변경과 정책 검증을 대신하지 않는다.

## 최신 develop과 통합할 때 반드시 함께 수정할 곳

이번 작업 트리에는 실제 SupabasePatientRepository와 PatientWithUserDTO가 없다. 2026-10-18 원격 조회한 origin/develop `03e5a22`에서 다음 구현을 확인했다. 이 Draft는 #107의 브랜치를 상속하므로 해당 파일을 임의로 복사해 넣지 않았다. #107 병합 후 최신 develop으로 재정렬할 때 최신 파일을 보존하면서 아래 변경을 반영해야 서버 조회에서 이름이 유실되지 않는다.

- `ToDoc/Data/DTOs/User/PatientWithUserDTO.swift`: optional `carcinomaOtherName`, CodingKeys의 `carcinoma_other_name` 추가. `toDomain()`에서 기타 이름 유효성을 확인하고 CarcinomaDetail.otherName으로 전달.
- `ToDoc/Data/Repositories/Supabase/SupabasePatientRepository.swift`: 공통 `columns`, `findByName`, `findByDoctorId`의 명시적 select 세 곳에 `carcinoma_other_name` 추가. 저장은 이번 PatientDTO의 인코딩 사용.
- DTO 왕복 테스트에 joined patient+user 응답을 추가하고 실제 upsert → 재조회에서 이름/unknown/NULL 초기화를 검증.
- 이 후속을 완료하기 전에는 실제 서버 연결 완료 또는 그대로 병합·배포 가능한 PR이라고 표시하지 않는다.

## 화면·팀 연결 변경

- SignupStageChoice의 `other`와 SignupScreenState.otherStage를 제거했다.
- SignupScreenState.usesOtherCancer는 `cancerType == .other`를 읽는 계산 값이다. 선택 시 cancerType을 변경한다.
- DiagnosisChange는 `carcinoma(CarcinomaType, otherName: String? = nil)`이다. 설정 VM은 이 payload의 이름을 저장하고, 조회한 값을 다시 주입해야 한다.
- 기존 `CarcinomaDetail(carcinoma:stage:)` 호출은 유지된다. 기타는 `otherName:`을 전달한다.
- 이름 표시에는 `CarcinomaDetail.carcinomaDisplayName`을 사용한다. enum.displayName만 쓰면 실제 기타 이름 대신 ‘기타’가 나온다.
- 홈/알림/케어콜 등의 새로운 VM을 이번 변경에 추가하지 않았다.

## PR 본문에 넣을 설명

암종 선택에 기타 자유 입력을 연결하고, 병기를 0~4기와 ‘모르겠어요’로 정리했습니다. 기타 이름은 CarcinomaDetail.otherName 및 PatientDTO의 carcinoma_other_name으로 보존하며, 일반 암종으로 변경할 때는 NULL로 지웁니다. 가입 검증·가입 재시도·최종 확인·마이페이지 입력에 같은 규칙을 적용했습니다.

서버 선행 조건은 patients.carcinoma_other_name nullable text 컬럼, carcinoma_type의 other, carcinoma_stage의 unknown 허용입니다. 최신 develop의 joined DTO와 명시적 select에도 새 필드를 연결해야 합니다. 서버 적용과 실제 DB 검증은 별도이며, Preview/단위 테스트 통과로 대체하지 않습니다.

이 계약은 Draft PR의 본문과 저장소 문서로 공유합니다. 별도 팀 메시지는 보내지 않습니다.
