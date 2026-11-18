//
//  PainLiveActivity.swift
//  ToDoc
//
//  Created by Andy An on 11/12/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

nonisolated struct PainLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        
    }
    
    var medicationTakenAt: Date
    var recordID: UUID?
    var followUpAt: Date?

    var timerEndsAt: Date {
        if let followUpAt { return followUpAt }
        #if DEBUG
        return medicationTakenAt.addingTimeInterval(60)
        #else
        return medicationTakenAt.addingTimeInterval(3_600)
        #endif
    }
}

struct PainLiveActivity: Widget {
    let painURL = URL(string: "todoc://record/pain")
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PainLiveActivityAttributes.self) { context in
            let medicationTakenAt = context.attributes.medicationTakenAt
            let timerEndsAt = context.attributes.timerEndsAt
            
            VStack(alignment: .center, spacing: 0) {

                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    if context.isStale {
                        Image("ScriptHangno")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 184, height: 123)
                            .frame(width: 74, height: 87, alignment: .top)
                            .clipped()
                            .offset(y: 18)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("통증을 기록해주세요")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            
                            
                            Text("진통제 복용 후 1시간이 지났어요!")
                                .font(.system(size: 14))
                                .foregroundStyle(Color("textDisabled"))
                        }
                        .multilineTextAlignment(.trailing)
                        .padding(.bottom, 12)
                    } else {
                        Image("PillHangno")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 80)
                            .frame(width: 70, height: 80, alignment: .top)
                            .clipped()
                            .offset(y: 18)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(timerInterval: medicationTakenAt...timerEndsAt)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("진통제 복용 1시간 뒤 변화를 기록해요.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color("textDisabled"))
                        }
                        .multilineTextAlignment(.trailing)
                        .padding(.bottom, 12)
                    }
                }
                
                painRecordCapsule(timerInterval: medicationTakenAt...timerEndsAt)
            }
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .widgetURL(painURL)
        } dynamicIsland: { context in
            DynamicIsland {
                let medicationTakenAt = context.attributes.medicationTakenAt
                let timerEndsAt = context.attributes.timerEndsAt
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .center, spacing: 0) {
                        if context.isStale {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("통증을 기록해주세요")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                
                                
                                Text("진통제 복용 후 1시간이 지났어요!")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color("textDisabled"))
                            }
                            .multilineTextAlignment(.trailing)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .background(alignment: .bottomLeading) {
                                Image("ScriptHangno")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 184, height: 123)
                                    .frame(width: 74, height: 87, alignment: .top)
                                    .clipped()
                                    .offset(y: 14)
                                    .accessibilityHidden(true)
                            }
                        } else {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(timerInterval: medicationTakenAt...timerEndsAt)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                
                                Text("진통제 복용 1시간 뒤 변화를 기록해요.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color("textDisabled"))
                            }
                            .multilineTextAlignment(.trailing)
                            .padding(.bottom, 8)
                            .background(alignment: .bottomLeading) {
                                Image("PillHangno")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 80)
                                    .frame(width: 70, height: 80, alignment: .top)
                                    .clipped()
                                    .offset(y: 14)
                                    .accessibilityHidden(true)
                            }
                        }
                        
                        
                        painRecordLink(timerInterval: medicationTakenAt...timerEndsAt)
                    }
                }
            } compactLeading: {
                Image(systemName: "cross.vial")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 24)
            } compactTrailing: {
                PainIslandCountdown(attributes: context.attributes, minimal: false)
            } minimal: {
                PainIslandCountdown(attributes: context.attributes, minimal: true)
            }
            .widgetURL(painURL)
            .keylineTint(Color("LiveActivityGreen"))
            .contentMargins(.leading, 20, for: .expanded)
            .contentMargins(.trailing, 20, for: .expanded)
            .contentMargins(.horizontal, 2, for: .minimal)
            .contentMargins(.vertical, 0, for: .minimal)
        }
    }

    @ViewBuilder
    private func painRecordLink(timerInterval: ClosedRange<Date>) -> some View {
        if let painURL {
            Link(destination: painURL) {
                painRecordCapsule(timerInterval: timerInterval)
            }
        } else {
            painRecordCapsule(timerInterval: timerInterval)
        }
    }

    private func painRecordCapsule(timerInterval: ClosedRange<Date>) -> some View {
        ZStack {
            Capsule().fill(Color("LiveActivityGrey"))

            ProgressView(timerInterval: timerInterval, countsDown: false)
                .labelsHidden()
                .tint(Color("LiveActivityGreen"))
                .scaleEffect(x: 1, y: 16)
                .accessibilityHidden(true)

            Label("통증 기록하러 가기", systemImage: "cross.vial")
                .foregroundStyle(Color("AnswerGreen"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .clipShape(.capsule)
        .contentShape(.capsule)
    }
}

/// iPhone switches to minimal presentation when another app also has a Live Activity.
/// Keep the countdown visible there too, within the 45 × 36.67 pt minimal bounds.
private struct PainIslandCountdown: View {
    let attributes: PainLiveActivityAttributes
    let minimal: Bool
    @Environment(\.isDynamicIslandLimitedInWidth) private var limitedWidth

    private var interval: ClosedRange<Date> { attributes.medicationTakenAt...attributes.timerEndsAt }

    var body: some View {
        Text(timerInterval: interval, countsDown: true, showsHours: false)
            .font(.system(size: limitedWidth ? 9 : (minimal ? 12 : 15), weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.center)
            .frame(width: limitedWidth ? 24 : (minimal ? 40 : 49), height: 24)
            .accessibilityLabel("통증 기록까지 남은 시간")
            .accessibilityValue(Text(timerInterval: interval, countsDown: true, showsHours: false))
    }
}

extension PainLiveActivityAttributes {
    fileprivate static var preview: PainLiveActivityAttributes {
        PainLiveActivityAttributes(medicationTakenAt: Date.now)
    }
}

#Preview("Notification", as: .content, using: PainLiveActivityAttributes.preview) {
    PainLiveActivity()
} contentStates: {
    PainLiveActivityAttributes.ContentState()
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: PainLiveActivityAttributes.preview) {
    PainLiveActivity()
} contentStates: {
    PainLiveActivityAttributes.ContentState()
}

#Preview("Compact", as: .dynamicIsland(.compact), using: PainLiveActivityAttributes.preview) {
    PainLiveActivity()
} contentStates: {
    PainLiveActivityAttributes.ContentState()
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: PainLiveActivityAttributes.preview) {
    PainLiveActivity()
} contentStates: {
    PainLiveActivityAttributes.ContentState()
}
