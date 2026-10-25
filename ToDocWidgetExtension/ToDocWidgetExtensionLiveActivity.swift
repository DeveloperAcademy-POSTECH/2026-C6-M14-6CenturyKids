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
                    Text(context.state.sentence)
                    Text(context.attributes.name)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button(action: {
                    
                }) {
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
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            .widgetURL(symptomURL)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Image(context.attributes.image)
                    Text(context.attributes.name)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.sentence)
                        .foregroundStyle(.gray)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    
                }
            } compactLeading: {
                Image("DynamicIslandCompactLeading")
            } compactTrailing: {
                Image(systemName: "stethoscope")
            } minimal: {
                Image("DynamicIslandMinimal")
            }
            .widgetURL(symptomURL)
            .keylineTint(Color.red)
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
