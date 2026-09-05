//
//  ScreenTimeNextWidgetsLiveActivity.swift
//  ScreenTimeNextWidgets
//
//  Created by apple on 9/5/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ScreenTimeNextWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ScreenTimeNextWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenTimeNextWidgetsAttributes.self) { context in
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

extension ScreenTimeNextWidgetsAttributes {
    fileprivate static var preview: ScreenTimeNextWidgetsAttributes {
        ScreenTimeNextWidgetsAttributes(name: "World")
    }
}

extension ScreenTimeNextWidgetsAttributes.ContentState {
    fileprivate static var smiley: ScreenTimeNextWidgetsAttributes.ContentState {
        ScreenTimeNextWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ScreenTimeNextWidgetsAttributes.ContentState {
         ScreenTimeNextWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ScreenTimeNextWidgetsAttributes.preview) {
   ScreenTimeNextWidgetsLiveActivity()
} contentStates: {
    ScreenTimeNextWidgetsAttributes.ContentState.smiley
    ScreenTimeNextWidgetsAttributes.ContentState.starEyes
}
