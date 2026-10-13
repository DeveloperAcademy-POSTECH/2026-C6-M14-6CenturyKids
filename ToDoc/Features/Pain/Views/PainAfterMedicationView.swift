import SwiftUI

struct PainAfterMedicationView: View {
    let locations: [BodyLocation]
    let before: Int
    @Binding var score: Int?
    var isSaving = false
    var errorMessage: String?
    var onPrevious: (() -> Void)?
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?
    var body: some View {
        PainScoreInputView(locations: locations, score: $score, before: before, isSaving: isSaving,
                           errorMessage: errorMessage, onPrevious: onPrevious, onNext: onSave, onClose: onClose)
    }
}

#Preview {
    @Previewable @State var score: Int? = 3
    PainAfterMedicationView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                            before: 7, score: $score, onPrevious: {}, onSave: {})
}
