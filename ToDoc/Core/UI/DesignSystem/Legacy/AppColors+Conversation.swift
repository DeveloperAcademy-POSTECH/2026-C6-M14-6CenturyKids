import SwiftUI

extension AppColors {
    enum CareCall {
        static let progressHighlight = Color(red: 214 / 255, green: 242 / 255, blue: 163 / 255)
        static let portraitBottom = Color(white: 230 / 255)
        static let listeningPortrait = Color(white: 236 / 255)
        static let editAction = Color(white: 152 / 255)
        static let summarySurface = Color(uiColor: .systemGray5)
        static let summarySecondary = Color.secondary
        static let summarySlider = Color(white: 110 / 255)
        static let deleteAction = Color(red: 1, green: 33 / 255, blue: 33 / 255)
        static let doneAction = Color(red: 33 / 255, green: 118 / 255, blue: 1)
        static let nativeDoneAction = Color.blue
        static let selectionBorder = Color("DesignSystem/PrimaryBorderTop")
        static let pendingText = Color(red: 112 / 255, green: 145 / 255, blue: 55 / 255)
        static let pendingFill = Color(red: 214 / 255, green: 228 / 255, blue: 190 / 255)
        static let pendingBorder = Color(red: 223 / 255, green: 237 / 255, blue: 198 / 255)
        static let wheelAdjacent = Color(white: 206 / 255)
        static let wheelDistant = Color(white: 235 / 255)
        static let incomingSubtitle = Color(white: 216 / 255)
        static let incomingControlText = Color(white: 231 / 255)
        static let incomingEnd = rgb(234, 77, 62)
        static let incomingAnswer = rgb(118, 213, 113)

        private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
            Color(red: r / 255, green: g / 255, blue: b / 255)
        }

        // Figma의 수신 화면 전용 합성 그라데이션. 다른 화면의 surface와 구분합니다.
        static let incomingBackground = LinearGradient(stops: [
            .init(color: rgb(230, 236, 244), location: 0.10509),
            .init(color: rgb(194, 238, 130), location: 2.4669)
        ], startPoint: .top, endPoint: .bottom)
        static let incomingShade = LinearGradient(stops: [
            .init(color: rgb(110, 116, 124).opacity(0.82), location: 0),
            .init(color: rgb(123, 133, 121).opacity(0.82), location: 0.62019),
            .init(color: rgb(107, 116, 106).opacity(0.82), location: 0.79327),
            .init(color: rgb(82, 90, 78).opacity(0.82), location: 0.913462),
            .init(color: rgb(36, 39, 33).opacity(0.82), location: 1)
        ], startPoint: .top, endPoint: .bottom)
        static let incomingMenu = LinearGradient(stops: [
            .init(color: rgb(94, 104, 92).opacity(0), location: 0),
            .init(color: rgb(93, 101, 92).opacity(0.18), location: 0.086538),
            .init(color: rgb(83, 91, 80).opacity(0.47), location: 0.20673),
            .init(color: rgb(80, 87, 77).opacity(0.67), location: 0.29327),
            .init(color: rgb(79, 85, 76).opacity(0.77), location: 0.37981),
            .init(color: rgb(81, 87, 78).opacity(0.698), location: 0.47115),
            .init(color: rgb(99, 105, 94).opacity(0), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }
}

extension AppGradients {
    static let conversationProgress = LinearGradient(
        colors: [AppColors.primary, AppColors.CareCall.progressHighlight, AppColors.primary],
        startPoint: .leading, endPoint: .trailing)
    static let conversationPortrait = LinearGradient(
        colors: [AppColors.Surface.progressTrack, AppColors.CareCall.portraitBottom],
        startPoint: .top, endPoint: .bottom)
    static let conversationListeningPortrait = LinearGradient(
        colors: [AppColors.CareCall.listeningPortrait, AppColors.CareCall.listeningPortrait],
        startPoint: .top, endPoint: .bottom)
}

extension AppSurfaceToken {
    static let conversationInput = Self(fill: AppColors.Surface.input, cornerRadius: AppMetrics.Conversation.inputRadius)
    static let conversationSummary = Self(fill: AppColors.CareCall.summarySurface, cornerRadius: 26)
}
