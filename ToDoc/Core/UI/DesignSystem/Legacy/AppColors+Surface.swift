import SwiftUI

extension AppColors {
    static let surface = Color.white

    enum Surface {
        static let control = AppColors.Button.backBackground // #F4F4F4
        static let input = Color(white: 243 / 255)
        static let progressTrack = Color(white: 241 / 255)
    }
    enum Feedback {
        static let error = Color.red
        static let destructive = Color.red
    }
}

extension AppColors.Text {
    static let inverse = Color.white
    static let control = AppColors.Button.secondaryForeground // #656565
    static let placeholder = Color(white: 141 / 255)
    static let subdued = Color(white: 79 / 255)
}
