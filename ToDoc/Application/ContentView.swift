import SwiftUI

struct ContentView: View {
    let container: DependencyContainer

    var body: some View {
        PatientFlowCompositionView(container: container)
    }
}
