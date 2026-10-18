import SwiftUI

extension AppSurfaceToken {
    static func previsitCard(selected: Bool = false) -> Self {
        Self(fill: selected ? AppColors.Previsit.selected : AppColors.surface,
             cornerRadius: AppMetrics.Previsit.cardRadius,
             border: selected ? AppColors.primary : .clear, borderWidth: 1)
    }
    static let previsitPrompt = Self(fill: AppColors.surface, cornerRadius: 40)
    static let notification = Self(fill: AppColors.surface, cornerRadius: AppMetrics.Notification.cardRadius)
    static let homePrimary = Self(fill: AppColors.primary, cornerRadius: AppMetrics.Home.entryRadius)
    static let homeSecondary = Self(fill: AppColors.Surface.control, cornerRadius: AppMetrics.Home.entryRadius)
}

extension AppMetrics {
    enum Previsit { static let cardRadius: CGFloat = 30 }
    enum Notification { static let cardRadius: CGFloat = 22 }
    enum Home { static let entryRadius: CGFloat = 32 }
}
