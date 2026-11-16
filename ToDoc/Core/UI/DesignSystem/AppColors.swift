import SwiftUI

/// 최신 Figma Semantic 색상 81개. 기존 화면용 별칭은 Legacy에 있습니다.
enum AppColors {
    /// Figma Semantic 색상. Asset 경로는 원본 변수 이름과 그룹을 유지합니다.
    enum Semantic {
        enum Primary {
            static let `default` = Color("DesignSystem/Semantic/primary/default")
            static let disabled = Color("DesignSystem/Semantic/primary/disabled")
            static let pressed = Color("DesignSystem/Semantic/primary/pressed")
        }

        enum Destructive {
            static let `default` = Color("DesignSystem/Semantic/destructive/default")
            static let pressed = Color("DesignSystem/Semantic/destructive/pressed")
        }

        enum Text {
            static let `default` = Color("DesignSystem/Semantic/text/default")
            static let sub = Color("DesignSystem/Semantic/text/sub")
            static let placeholder = Color("DesignSystem/Semantic/text/placeholder")
            static let disabled = Color("DesignSystem/Semantic/text/disabled")
            static let error = Color("DesignSystem/Semantic/text/error")
            static let action = Color("DesignSystem/Semantic/text/action")
            static let onPrimary = Color("DesignSystem/Semantic/text/on-primary")
            static let onPrimaryDisabled = Color("DesignSystem/Semantic/text/on-primary-disabled")
            static let onDestructive = Color("DesignSystem/Semantic/text/on-destructive")
            static let inverse = Color("DesignSystem/Semantic/text/inverse")
        }

        enum Background {
            static let `default` = Color("DesignSystem/Semantic/background/default")
            static let inverse = Color("DesignSystem/Semantic/background/inverse")
            static let error = Color("DesignSystem/Semantic/background/error")
            static let secondary = Color("DesignSystem/Semantic/background/secondary")
            static let surface = Color("DesignSystem/Semantic/background/surface")
            static let selected = Color("DesignSystem/Semantic/background/selected")
            static let primarySubtle = Color("DesignSystem/Semantic/background/primary-subtle")
            static let inverseSubtle = Color("DesignSystem/Semantic/background/inverse-subtle")
        }

        enum Border {
            static let `default` = Color("DesignSystem/Semantic/border/default")
            static let error = Color("DesignSystem/Semantic/border/error")
            static let focus = Color("DesignSystem/Semantic/border/focus")
            static let selected = Color("DesignSystem/Semantic/border/selected")
        }

        enum Indicator {
            static let active = Color("DesignSystem/Semantic/indicator/active")
            static let inactive = Color("DesignSystem/Semantic/indicator/inactive")
            static let selected = Color("DesignSystem/Semantic/indicator/selected")
        }

        enum Chart {
            static let track = Color("DesignSystem/Semantic/chart/track")

            enum Score {
                static let score0 = Color("DesignSystem/Semantic/chart/score/0")
                static let score25 = Color("DesignSystem/Semantic/chart/score/25")
                static let score50 = Color("DesignSystem/Semantic/chart/score/50")
                static let score75 = Color("DesignSystem/Semantic/chart/score/75")
                static let score100 = Color("DesignSystem/Semantic/chart/score/100")
            }

            enum Category {
                enum Sky {
                    static let light = Color("DesignSystem/Semantic/chart/category/sky/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/sky/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/sky/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/sky/text")
                }

                enum Green {
                    static let light = Color("DesignSystem/Semantic/chart/category/green/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/green/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/green/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/green/text")
                }

                enum Blue {
                    static let light = Color("DesignSystem/Semantic/chart/category/blue/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/blue/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/blue/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/blue/text")
                }

                enum Yellow {
                    static let light = Color("DesignSystem/Semantic/chart/category/yellow/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/yellow/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/yellow/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/yellow/text")
                }

                enum Cyan {
                    static let light = Color("DesignSystem/Semantic/chart/category/cyan/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/cyan/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/cyan/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/cyan/text")
                }

                enum Purple {
                    static let light = Color("DesignSystem/Semantic/chart/category/purple/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/purple/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/purple/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/purple/text")
                }

                enum Pink {
                    static let light = Color("DesignSystem/Semantic/chart/category/pink/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/pink/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/pink/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/pink/text")
                }

                enum Orange {
                    static let light = Color("DesignSystem/Semantic/chart/category/orange/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/orange/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/orange/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/orange/text")
                }

                enum Lime {
                    static let light = Color("DesignSystem/Semantic/chart/category/lime/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/lime/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/lime/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/lime/text")
                }

                enum Gray {
                    static let light = Color("DesignSystem/Semantic/chart/category/gray/light")
                    static let fill = Color("DesignSystem/Semantic/chart/category/gray/fill")
                    static let dark = Color("DesignSystem/Semantic/chart/category/gray/dark")
                    static let text = Color("DesignSystem/Semantic/chart/category/gray/text")
                }
            }
        }

        enum Avatar {
            static let calm = Color("DesignSystem/Semantic/avatar/calm")
            static let worried = Color("DesignSystem/Semantic/avatar/worried")
            static let anxious = Color("DesignSystem/Semantic/avatar/anxious")
            static let notReady = Color("DesignSystem/Semantic/avatar/not-ready")
            static let unsure = Color("DesignSystem/Semantic/avatar/unsure")
        }
    }
}
