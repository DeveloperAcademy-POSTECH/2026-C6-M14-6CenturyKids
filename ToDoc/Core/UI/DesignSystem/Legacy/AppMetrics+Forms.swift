import CoreGraphics

extension AppMetrics {
    enum Settings {
        static let groupRadius: CGFloat = 14
        static let separatorHeight: CGFloat = 0.64
        static let rowMinimumHeight: CGFloat = 52
        static let inputMinimumHeight: CGFloat = 54
        static let compactRowMinimumHeight: CGFloat = 50
        static let profileMinimumHeight: CGFloat = 86
        static let headerActionWidth: CGFloat = 64
    }

    enum Auth {
        static let inputRadius: CGFloat = 16
        static let inputMinimumHeight: CGFloat = 60
        static let informationRadius: CGFloat = 20
        static let roleRadius: CGFloat = 24
        static let alternateSignInRadius: CGFloat = 14
        static let alternateSignInMinimumHeight: CGFloat = 56
        static let inputBorderWidth: CGFloat = 1
        static let loginFocusBorderWidth: CGFloat = 3
    }
}

extension AppSpacing {
    enum Settings {
        static let screenHorizontal: CGFloat = 20
        static let inputGap: CGFloat = 20
    }

    enum Auth {
        static let formGap: CGFloat = 28
        static let fieldLabelGap: CGFloat = 10
        static let inputPadding: CGFloat = 18
        static let informationPadding: CGFloat = 20
    }
}
