//
//  AppIntent.swift
//  RecorderWidgetExtension
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "A simple configuration." }

    @Parameter(title: "Favorite Emoji", default: "😀")
    var favoriteEmoji: String
}
