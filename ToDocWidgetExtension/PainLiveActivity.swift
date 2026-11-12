//
//  PainLiveActivity.swift
//  ToDoc
//
//  Created by Andy An on 11/12/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct PainLiveActivityAttributes: ActivityAttributes {
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
                
                ZStack {
                    Capsule()
                        .fill(Color.gray)
                        .frame(width: .infinity, height: 52)
                    
                    ProgressView(timerInterval: medicationTakenAt...timerEndsAt, countsDown: false)
                        .labelsHidden()
                        .tint(Color("LiveActivityGreen"))
                        .scaleEffect(x: 1, y: 16)
                        .frame(width: .infinity)
                    
                    Label("통증 기록하러 가기", systemImage: "cross.vial")
                        .foregroundStyle(.white)
                }
                .clipShape(.capsule)
            }
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
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
                        
                        
                        ZStack {
                            Capsule()
                                .fill(Color.gray)
                                .frame(width: .infinity, height: 52)
                            
                            ProgressView(timerInterval: medicationTakenAt...timerEndsAt, countsDown: false)
                                .labelsHidden()
                                .tint(Color("LiveActivityGreen"))
                                .scaleEffect(x: 1, y: 16)
                                .frame(width: .infinity)
                            
                            Label("통증 기록하러 가기", systemImage: "cross.vial")
                                .foregroundStyle(.white)
                        }
                        .clipShape(.capsule)
                    }
                }
            } compactLeading: {
                let medicationTakenAt = context.attributes.medicationTakenAt
                let timerEndsAt = context.attributes.timerEndsAt
                
                Text(timerInterval: medicationTakenAt...timerEndsAt)
                    .font(.caption)
                    .frame(width: 30)
            } compactTrailing: {
                Image(systemName: "cross.vial")
            } minimal: {
                let medicationTakenAt = context.attributes.medicationTakenAt
                let timerEndsAt = context.attributes.timerEndsAt
                
                Text(timerInterval: medicationTakenAt...timerEndsAt)
                    .font(.caption)
                    .frame(width: 30)
            }
            .widgetURL(painURL)
            .keylineTint(Color("LiveActivityGreen"))
            .contentMargins(.leading, 20, for: .expanded)
            .contentMargins(.trailing, 20, for: .expanded)
            .contentMargins(.horizontal, 11, for: .minimal)
            .contentMargins(.vertical, 7, for: .minimal)
        }
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
