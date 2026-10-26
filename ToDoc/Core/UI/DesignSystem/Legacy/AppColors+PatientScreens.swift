import SwiftUI

extension AppColors {
    enum Home {
        static let backgroundTop = Color(white: 249 / 255)
        static let backgroundBottom = Color(white: 236 / 255)
        static let doctorCaption = Color(white: 93 / 255)
        static let previsitBorder = Color(white: 128 / 255)
        static let primaryTitle = Color(red: 53 / 255, green: 77 / 255, blue: 9 / 255)
        static let primaryCaption = Color(red: 118 / 255, green: 151 / 255, blue: 58 / 255)
        static let secondaryTitle = Color(white: 0.31)
        static let secondaryCaption = Color(white: 0.63)
    }

    enum Previsit {
        static let dim = Color.black.opacity(0.26)
        static let close = Color(white: 0.7)
        static let promptCaption = Color(white: 0.53)
        static let promptTitle = Color(white: 0.23)
        static let letterSignature = Color(white: 0.67)
        static let backIcon = Color(white: 0.32)
        static let backSurface = Color(white: 0.96)
        static let placeholder = Color(white: 0.37)
        static let moodCaption = Color(white: 0.55)
        static let title = Color(white: 0.11)
        static let selected = Color(red: 0.98, green: 0.99, blue: 0.95)
        static let nextIcon = Color(red: 0.57, green: 0.76, blue: 0.23)
        static let weekday = Color(white: 0.51)
        static let entry = Color(white: 0.31)
        static let entryDot = Color(red: 1, green: 0.33, blue: 0.28)
        static let emptyDot = Color.gray.opacity(0.5)

        enum Mood {
            static let candid = Color(red: 0.78, green: 0.92, blue: 0.63)
            static let comfortable = Color(red: 1, green: 0.83, blue: 0.27)
            static let slowly = Color(red: 1, green: 0.61, blue: 0.31)
            static let carefully = Color(red: 1, green: 0.36, blue: 0.31)
            static let unsure = Color(white: 0.76)
        }
    }

    enum Notification {
        static let metadata = Color(white: 133 / 255)
    }
}

extension AppGradients {
    static let homeBackground = LinearGradient(stops: [
        .init(color: AppColors.Home.backgroundTop, location: 0),
        .init(color: AppColors.Home.backgroundTop, location: 0.36538),
        .init(color: AppColors.Home.backgroundBottom, location: 0.48077),
        .init(color: AppColors.Home.backgroundBottom, location: 1)
    ], startPoint: .top, endPoint: .bottom)
}
