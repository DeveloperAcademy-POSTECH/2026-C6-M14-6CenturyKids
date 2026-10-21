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
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ToDocWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ToDocWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ToDocWidgetExtensionAttributes {
    fileprivate static var preview: ToDocWidgetExtensionAttributes {
        ToDocWidgetExtensionAttributes(name: "World")
    }
}

extension ToDocWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: ToDocWidgetExtensionAttributes.ContentState {
        ToDocWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ToDocWidgetExtensionAttributes.ContentState {
         ToDocWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ToDocWidgetExtensionAttributes.preview) {
   ToDocWidgetExtensionLiveActivity()
} contentStates: {
    ToDocWidgetExtensionAttributes.ContentState.smiley
    ToDocWidgetExtensionAttributes.ContentState.starEyes
}
