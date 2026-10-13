import SwiftUI

/// 사용자 확정: 병원명·담당의 직접 수정 대신 의사 코드로 연결 대상을 변경합니다.
struct HospitalInfoEditView: View {
    var state: HospitalConnectionScreenState?
    var body: some View { HospitalConnectionView(state: state, title: "병원 정보 수정") }
}
#Preview { NavigationStack { HospitalInfoEditView() } }
