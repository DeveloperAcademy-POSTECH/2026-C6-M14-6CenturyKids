import SwiftUI

extension AppSurfaceToken {
    static let settingsGroup = Self(fill: AppColors.surface, cornerRadius: AppMetrics.Settings.groupRadius)
    static let authInformation = Self(fill: AppColors.secondary, cornerRadius: AppMetrics.Auth.informationRadius)
    static let authInput = Self(fill: AppColors.secondary, cornerRadius: AppMetrics.Auth.inputRadius)
    static let authAlternateSignIn = Self(fill: AppColors.secondary, cornerRadius: AppMetrics.Auth.alternateSignInRadius)

    static func authChoice(isSelected: Bool) -> Self {
        Self(fill: isSelected ? AppColors.primary : AppColors.secondary, cornerRadius: AppMetrics.Auth.inputRadius)
    }

    static func authRole(isSelected: Bool) -> Self {
        Self(fill: isSelected ? AppColors.primary : AppColors.secondary, cornerRadius: AppMetrics.Auth.roleRadius)
    }
}
