//
//  ToDocWidgetExtensionLiveActivity.swift
//  ToDocWidgetExtension
//
//  Created by 앤디 on 10/21/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ToDocWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var sentence: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
    var image: String
}

struct ToDocWidgetExtensionLiveActivity: Widget {
    let symptomURL = URL(string: "todoc://record/symptoms")
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ToDocWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            HStack(spacing: 0) {
                Image(context.attributes.image)
                    .padding(.leading, 20)
                    .padding(.trailing, 16)
                
                VStack(alignment: .leading) {
                    Text(context.attributes.name)
                        .fontWeight(.bold)
                    Text(context.state.sentence)
                }
                
                Spacer()
                
                Link(
                    destination: URL(
                    string: "todoc://record/symptoms?mode=voice"
                )!
                ) {
                    Image(systemName: "stethoscope")
                        .fontWeight(.bold)
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                .background(Color("LiveActivityGreen"))
                .clipShape(.circle)
                .padding(.trailing, 20)
            }
            .frame(height: 96)
            .foregroundStyle(.white)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            .widgetURL(symptomURL)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Image(context.attributes.image)
                        .resizable()
                        .frame(width: 60, height: 60)
                        .scaledToFit()
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.name)
                            .fontWeight(.bold)
                        Text(context.state.sentence)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(
                        destination: URL(
                        string: "todoc://record/symptoms?mode=voice"
                    )!
                    ) {
                        Image(systemName: "stethoscope")
                            .fontWeight(.bold)
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)
                    .background(Color("LiveActivityGreen"))
                    .clipShape(.circle)
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
            .contentMargins(.all, 20, for: .expanded)
            .contentMargins(.horizontal, 11, for: .minimal)
            .contentMargins(.vertical, 7, for: .minimal)
        }
    }
}

extension ToDocWidgetExtensionAttributes {
    fileprivate static var preview: ToDocWidgetExtensionAttributes {
        ToDocWidgetExtensionAttributes(name: "Dr.학로", image: "HangnoWithoutBackground")
    }
}

extension ToDocWidgetExtensionAttributes.ContentState {
    fileprivate static var normal: ToDocWidgetExtensionAttributes.ContentState {
        ToDocWidgetExtensionAttributes.ContentState(sentence: "오늘 하루는 어떠셨나요?")
     }
     
     fileprivate static var emergency: ToDocWidgetExtensionAttributes.ContentState {
         ToDocWidgetExtensionAttributes.ContentState(sentence: "오늘 기록이 아직 없어요!")
     }
}

#Preview("Notification", as: .content, using: ToDocWidgetExtensionAttributes.preview) {
   ToDocWidgetExtensionLiveActivity()
} contentStates: {
    ToDocWidgetExtensionAttributes.ContentState.normal
    ToDocWidgetExtensionAttributes.ContentState.emergency
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: ToDocWidgetExtensionAttributes.preview) {
   ToDocWidgetExtensionLiveActivity()
} contentStates: {
    ToDocWidgetExtensionAttributes.ContentState.normal
    ToDocWidgetExtensionAttributes.ContentState.emergency
}

#Preview("Compact", as: .dynamicIsland(.compact), using: ToDocWidgetExtensionAttributes.preview) {
   ToDocWidgetExtensionLiveActivity()
} contentStates: {
    ToDocWidgetExtensionAttributes.ContentState.normal
    ToDocWidgetExtensionAttributes.ContentState.emergency
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: ToDocWidgetExtensionAttributes.preview) {
   ToDocWidgetExtensionLiveActivity()
} contentStates: {
    ToDocWidgetExtensionAttributes.ContentState.normal
    ToDocWidgetExtensionAttributes.ContentState.emergency
}
