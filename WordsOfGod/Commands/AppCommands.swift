//
//  AppCommands.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct AppCommands: Commands {
    @Bindable private var settings = AppSettings.shared
    private let player = RecitationPlayer.shared
    private let reader = Reader.shared

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Bigger Text") { settings.adjustFontSizes(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller Text") { settings.adjustFontSizes(by: -1) }
                .keyboardShortcut("-", modifiers: .command)

            Picker("Arabic Font", selection: $settings.quranFont) {
                ForEach(QuranFont.allCases) { Text($0.name).tag($0) }
            }
            Picker("Arabic Script", selection: $settings.script) {
                ForEach(ArabicScript.allCases) { Text($0.name).tag($0) }
            }
            Toggle("Tajweed Colors", isOn: $settings.showsTajweed)
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(settings.script != .uthmani)
            Toggle("Show Word Translation", isOn: $settings.showWordTranslation)
            Toggle("Show Transliteration", isOn: $settings.showTransliteration)
            Toggle("Follow Recitation", isOn: $settings.autoScroll)
            Toggle("Memorization Mode", isOn: $settings.memorizationMode)
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Divider()
        }

        CommandMenu("Playback") {
            Button(player.isActivelyPlaying ? "Pause" : "Play") { player.toggle() }
                .disabled(!player.isLoaded)
            Button("Next Verse") { player.nextVerse() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(!player.isLoaded || !player.canGoToNextVerse)
            Button("Previous Verse") { player.previousVerse() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(!player.isLoaded)

            Divider()

            Picker("Speed", selection: Binding(get: { settings.playbackRate }, set: { player.setRate($0) })) {
                ForEach(AudioPlayerBar.rates, id: \.self) { Text(AudioPlayerBar.rateLabel($0)).tag($0) }
            }
            Picker("Repeat Each Verse", selection: $settings.verseRepeatCount) {
                ForEach(RepeatCount.choices, id: \.self) { Text(RepeatCount.label($0)).tag($0) }
            }
            Picker("Repeat Range", selection: $settings.rangeRepeatCount) {
                ForEach(RepeatCount.choices, id: \.self) { Text(RepeatCount.label($0)).tag($0) }
            }
            Button("Clear Repeat Range") { player.clearRange() }
                .disabled(!player.hasRange)

            Divider()

            Button(player.isPresentationVisible ? "Exit Presentation" : "Presentation") { reader.togglePresentation() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(!player.isLoaded)
            Button("Stop") { player.stop() }
                .disabled(!player.isLoaded)
        }

        CommandMenu("Reciter") {
            if settings.reciters.isEmpty {
                Text(settings.recitersError ?? "Loading…")
            } else {
                Picker("Reciter", selection: $settings.selectedReciterId) {
                    ForEach(settings.reciters) { Text($0.displayName).tag($0.id) }
                }
                .pickerStyle(.inline)
            }
        }

        CommandMenu("Translation") {
            ForEach(settings.selectedTranslationIds, id: \.self) { id in
                Toggle(translationName(id), isOn: Binding(
                    get: { settings.isTranslationSelected(id) },
                    set: { settings.setTranslation(id, selected: $0) }
                ))
            }
            if !settings.selectedTranslationIds.isEmpty { Divider() }

            Picker("Word-by-Word Language", selection: $settings.wordTranslationLanguageCode) {
                ForEach(WordTranslationLanguage.supported) { Text($0.name).tag($0.code) }
            }

            Divider()

            #if os(macOS)
            SettingsLink { Text("Manage Translations…") }
            #else
            Button("Manage Translations…") { reader.isShowingSettings = true }
            #endif
        }
    }

    private func translationName(_ id: Int) -> String {
        guard let translation = settings.translations.first(where: { $0.id == id }) else { return "Translation \(id)" }
        return "\(translation.name) (\(translation.language_name.capitalized))"
    }
}
