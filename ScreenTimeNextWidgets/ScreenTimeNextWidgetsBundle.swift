//  ScreenTimeNextWidgetsBundle.swift
//  ScreenTimeNextWidgets
//
//  D-014. The widget bundle exists only to host the Live Activity.

import WidgetKit
import SwiftUI

@main
struct ScreenTimeNextWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ScreenTimeNextLiveActivity()
    }
}
