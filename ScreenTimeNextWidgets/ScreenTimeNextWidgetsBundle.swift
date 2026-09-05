//
//  ScreenTimeNextWidgetsBundle.swift
//  ScreenTimeNextWidgets
//
//  Created by apple on 9/5/26.
//

import WidgetKit
import SwiftUI

@main
struct ScreenTimeNextWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ScreenTimeNextWidgets()
        ScreenTimeNextWidgetsControl()
        ScreenTimeNextWidgetsLiveActivity()
    }
}
