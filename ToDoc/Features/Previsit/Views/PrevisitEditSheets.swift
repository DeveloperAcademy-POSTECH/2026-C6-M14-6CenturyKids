import SwiftUI

/// Figma '진료 전 기록 바텀시트 플로우' 기록 수정 시트(하고싶은말 1850:48711, 기분 1850:48606). 저장은 부모가 ViewModel로 합니다.
enum PrevisitEdit: String, Identifiable {
    case letter, mood
    var id: Self { self }
}

/// 하고싶은말 수정: 흰 시트 위 Text Area(230), 열리면 바로 키보드
struct PrevisitLetterEditSheet: View {
    @State private var text: String
    let onConfirm: (String) -> Void
    @FocusState private var focused: Bool
    @State private var sheetHeight: CGFloat = 400

    init(text: String, onConfirm: @escaping (String) -> Void) {
        _text = State(initialValue: text)
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 24) {
            PrevisitSheetHeader(title: "기록 수정") { onConfirm(text) }
            AppInputs.TextArea("선생님께 전할 이야기", text: Binding(
                get: { text },
                set: { text = String($0.prefix(200)) }
            ), placeholder: "예) 오늘 너무 힘들었어요…")
            .frame(height: 230)
            .focused($focused)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("previsitEdit.letter")
        }
        .padding(.bottom, 24)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(40)
        .presentationBackground(AppColors.Semantic.Background.surface)
        .onAppear { focused = true }
    }
}

/// 기분 수정: 다섯 기분 중 하나를 고르고 체크로 저장
struct PrevisitMoodEditSheet: View {
    @State private var selection: StateOfMind
    let onConfirm: (StateOfMind) -> Void
    @State private var sheetHeight: CGFloat = 600

    /// Figma 고른 칸 바탕(#F7FEE9)·칸 테두리(#F1F1F1). 디자인 시스템 색 목록에 아직 없어 여기 둡니다
    private static let selectedFill = Color(red: 247 / 255, green: 254 / 255, blue: 233 / 255)
    private static let rowBorder = Color(white: 241 / 255)

    init(selection: StateOfMind, onConfirm: @escaping (StateOfMind) -> Void) {
        _selection = State(initialValue: selection)
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 0) {
            PrevisitSheetHeader(title: "기록 수정") { onConfirm(selection) }
            VStack(spacing: 12) {
                ForEach(StateOfMind.editOrder, id: \.self, content: row)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(40)
        .presentationBackground(AppColors.Semantic.Background.default)
    }

    private func row(_ mood: StateOfMind) -> some View {
        let isSelected = selection == mood
        return Button { selection = mood } label: {
            HStack(spacing: 20) {
                PrevisitMoodFace(mood: mood)
                VStack(alignment: .leading, spacing: 4) {
                    if let caption = mood.caption {
                        Text(caption)
                            .appTypography(.caption)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                    }
                    Text(mood.title)
                        .appTypography(.labelLarge)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(minHeight: 96)
            .background(isSelected ? Self.selectedFill : AppColors.Semantic.Background.surface,
                        in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(Self.rowBorder, lineWidth: 1))
            .shadow(color: .black.opacity(isSelected ? 0.02 : 0), radius: 3, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(AppActions.PressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("previsitEdit.mood.\(mood.rawValue)")
    }
}
