//
//  WordsOfGodApp.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

@main
struct WordsOfGodApp: App {

    init() {
        QuranFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear { PlaybackKeyMonitor.install() }
                #endif
                .task { await AppSettings.shared.load() }
        }
        .commands { AppCommands() }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
