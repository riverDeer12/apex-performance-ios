//
//  TrainingActivityBundle.swift
//  TrainingActivity
//

import SwiftUI
import WidgetKit

@main
struct TrainingActivityBundle: WidgetBundle {
    var body: some Widget {
        TrainingLiveActivityWidget()
        // ApexHomeWidget() is ready but waits for the App Group
        // (group.<app id>) shared by the app and this extension: without it
        // the widget can't read what the app writes. Once the App Group is
        // set up on the Developer portal, add it back here together with the
        // com.apple.security.application-groups entitlement ($(APP_GROUP_ID))
        // of both targets.
    }
}
