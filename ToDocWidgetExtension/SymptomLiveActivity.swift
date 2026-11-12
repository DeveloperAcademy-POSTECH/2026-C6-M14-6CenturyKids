//
//  ToDocWidgetExtensionLiveActivity.swift
//  ToDocWidgetExtension
//
//  Created by 앤디 on 10/21/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SymptomLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var sentence: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
    var image: String
}

struct SymptomLiveActivity: Widget {
    let symptomURL = URL(string: "todoc://record/symptoms")
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SymptomLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(alignment: .center, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Image("LiveActivityHangno")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 114)
                        .frame(width: 88, height: 80, alignment: .top)
                        .clipped()
                        .offset(y: 26)
                        .accessibilityHidden(true)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.attributes.name)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text(context.state.sentence)
                            .font(.subheadline)
                            .foregroundStyle(Color("textDisabled"))
                    }
                    .multilineTextAlignment(.trailing)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .bottomTrailing)
                }
                
                HStack(spacing: 8) {
                    Link(destination: URL(string: "todoc://record/symptoms?mode=voice")!) {
                        Label("증상 대화하러 가기", systemImage: "phone.fill")
                            .font(.body)
                            .foregroundStyle(Color("AnswerGreen"))
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("LiveActivityGreen"), in: .capsule)
                            .contentShape(.capsule)
                    }

                    Button(action: {
                        Task {
                            
                        }
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Color("DeclineRed"))
                            .frame(width: 56, height: 56)
                            .background(Color("LiveActivityRed"), in: .circle)
                            .contentShape(.circle)
                    }
                    .accessibilityLabel("통화 거절")
                }
                .buttonStyle(.plain)
            }
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    expandedContent(context)
                }
            } compactLeading: {
                Image("HangnoWithoutBackground")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .scaledToFit()
            } compactTrailing: {
                Image(systemName: "stethoscope")
            } minimal: {
                Image("HangnoWithoutBackground")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .scaledToFit()
            }
            .widgetURL(symptomURL)
            .keylineTint(Color("LiveActivityGreen"))
            .contentMargins(.leading, 20, for: .expanded)
            .contentMargins(.trailing, 20, for: .expanded)
            .contentMargins(.horizontal, 11, for: .minimal)
            .contentMargins(.vertical, 7, for: .minimal)
        }
    }

    private func expandedContent(
        _ context: ActivityViewContext<SymptomLiveActivityAttributes>
    ) -> some View {
        let buttonHeight: CGFloat = 52

        return VStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.attributes.name)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text(context.state.sentence)
                    .font(.subheadline)
                    .foregroundStyle(Color("textDisabled"))
            }
            .multilineTextAlignment(.trailing)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .bottomTrailing)
            .background(alignment: .bottomLeading) {
                Image("LiveActivityHangno")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 114)
                    .frame(width: 88, height: 80, alignment: .top)
                    .clipped()
                    .offset(y: 3)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                Link(destination: URL(string: "todoc://record/symptoms?mode=voice")!) {
                    Label("증상 대화하러 가기", systemImage: "phone.fill")
                        .font(.body)
                        .foregroundStyle(Color("AnswerGreen"))
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .frame(height: buttonHeight)
                        .background(Color("LiveActivityGreen"), in: .capsule)
                        .contentShape(.capsule)
                }

                Button(action: {
                    Task {
                        
                    }
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color("DeclineRed"))
                        .frame(width: buttonHeight, height: buttonHeight)
                        .background(Color("LiveActivityRed"), in: .circle)
                        .contentShape(.circle)
                }
                .accessibilityLabel("통화 거절")
            }
            .buttonStyle(.plain)
        }
    }
}

extension SymptomLiveActivityAttributes {
    fileprivate static var preview: SymptomLiveActivityAttributes {
        SymptomLiveActivityAttributes(name: "Dr. 속닥이", image: "LiveActivityHangno")
    }
}

extension SymptomLiveActivityAttributes.ContentState {
    fileprivate static var normal: SymptomLiveActivityAttributes.ContentState {
        SymptomLiveActivityAttributes.ContentState(sentence: "오늘 하루는 어떠셨나요?")
     }
     
     fileprivate static var emergency: SymptomLiveActivityAttributes.ContentState {
         SymptomLiveActivityAttributes.ContentState(sentence: "오늘 기록이 아직 없어요!")
     }
}

#Preview("Notification", as: .content, using: SymptomLiveActivityAttributes.preview) {
   SymptomLiveActivity()
} contentStates: {
    SymptomLiveActivityAttributes.ContentState.normal
    SymptomLiveActivityAttributes.ContentState.emergency
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: SymptomLiveActivityAttributes.preview) {
   SymptomLiveActivity()
} contentStates: {
    SymptomLiveActivityAttributes.ContentState.normal
    SymptomLiveActivityAttributes.ContentState.emergency
}

#Preview("Compact", as: .dynamicIsland(.compact), using: SymptomLiveActivityAttributes.preview) {
   SymptomLiveActivity()
} contentStates: {
    SymptomLiveActivityAttributes.ContentState.normal
    SymptomLiveActivityAttributes.ContentState.emergency
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: SymptomLiveActivityAttributes.preview) {
   SymptomLiveActivity()
} contentStates: {
    SymptomLiveActivityAttributes.ContentState.normal
    SymptomLiveActivityAttributes.ContentState.emergency
}
