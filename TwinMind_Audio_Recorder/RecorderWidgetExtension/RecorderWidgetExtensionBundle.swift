//
//  RecorderWidgetExtensionBundle.swift
//  RecorderWidgetExtension
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import WidgetKit
import SwiftUI

@main
struct RecorderWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        RecorderWidgetExtension()
        RecorderWidgetExtensionLiveActivity()
    }
}
