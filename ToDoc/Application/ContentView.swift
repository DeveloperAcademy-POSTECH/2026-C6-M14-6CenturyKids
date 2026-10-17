import SwiftUI

/// 현재 팀이 함께 사용하는 기본 진입점입니다. develop의 홈·기록·설정 이동을 유지합니다.
/// PatientRepository 등의 연결이 끝나기 전에도 각 담당자가 기존 화면을 실행할 수 있습니다.
/// 홈을 표시하는 것과 인증 성공은 별개입니다. 여기서 가짜 환자나 로그인 세션을 만들지 않습니다.
struct ContentView: View {
    var body: some View {
        PatientFlowView()
    }
}

#Preview { ContentView() }
