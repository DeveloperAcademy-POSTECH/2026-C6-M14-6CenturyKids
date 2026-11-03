import SwiftUI

struct PainBeforeMedicationView: View {
    let locations: [BodyLocation]
    @Binding var score: Int?
    var isSaving = false
    var errorMessage: String?
    var onPrevious: (() -> Void)?
    var onReselectLocations: (() -> Void)?
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?
    var body: some View {
        PainScoreInputView(locations: locations, score: $score, isSaving: isSaving, errorMessage: errorMessage,
                           onPrevious: onPrevious, onReselectLocations: onReselectLocations, onNext: onNext, onClose: onClose)
    }
}

#Preview {
    @Previewable @State var score: Int? = 7
    PainBeforeMedicationView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                             score: $score, onPrevious: {}, onNext: {})
}
