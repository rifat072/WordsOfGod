//
//  DisplayMenu.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct DisplayMenu: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Menu {
            DisplayOptions()
        } label: {
            Label("Display", systemImage: "textformat.size")
        }
        .help("Text size and display options")
    }
}

struct DisplayOptions: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Button("Bigger Text", systemImage: "plus.magnifyingglass") { settings.adjustFontSizes(by: 1) }
        Button("Smaller Text", systemImage: "minus.magnifyingglass") { settings.adjustFontSizes(by: -1) }

        Divider()

Picker("Arabic Font", selection: $settings.quranFont) {
            ForEach(QuranFont.allCases) { Text($0.name).tag($0) }
        }

        Picker("Arabic Script", selection: $settings.script) {
            ForEach(ArabicScript.allCases) { Text($0.name).tag($0) }
        }

        Picker("Word-by-Word Language", selection: $settings.wordTranslationLanguageCode) {
            ForEach(WordTranslationLanguage.supported) { Text($0.name).tag($0.code) }
        }

        Divider()

Toggle("Tajweed Colors", isOn: $settings.showsTajweed)
            .disabled(settings.script != .uthmani)
        Toggle("Word Translation", isOn: $settings.showWordTranslation)
        Toggle("Transliteration", isOn: $settings.showTransliteration)
        Toggle("Follow Recitation", isOn: $settings.autoScroll)
        Toggle("Memorization Mode", isOn: $settings.memorizationMode)
    }
}
