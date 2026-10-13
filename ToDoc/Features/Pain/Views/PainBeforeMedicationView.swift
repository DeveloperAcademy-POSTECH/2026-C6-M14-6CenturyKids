import SwiftUI

struct PainBeforeMedicationView: View {
    let locations: [BodyLocation]
    @Binding var score: Int?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?
    var body: some View {
        PainScoreInputView(locations: locations, score: $score, onPrevious: onPrevious, onNext: onNext, onClose: onClose)
    }
}

#Preview {
    @Previewable @State var score: Int? = 7
    PainBeforeMedicationView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                             score: $score, onPrevious: {}, onNext: {})
}
