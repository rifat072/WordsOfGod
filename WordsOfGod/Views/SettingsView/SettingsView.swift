//
//  SettingsView.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct SettingsView: View {
    #if !os(macOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        #if os(macOS)
        TabView {
            Tab("Reading", systemImage: "textformat") {
                ReadingSettings()
            }
            Tab("Translations", systemImage: "character.book.closed") {
                TranslationPicker()
            }
            Tab("Audio", systemImage: "speaker.wave.2") {
                AudioSettings()
            }
        }
        .frame(width: 480, height: 520)
        #else
        NavigationStack {
            List {
                NavigationLink {
                    ReadingSettings().navigationTitle("Reading")
                } label: {
                    Label("Reading", systemImage: "textformat")
                }
                NavigationLink {
                    TranslationPicker().navigationTitle("Translations")
                } label: {
                    Label("Translations", systemImage: "character.book.closed")
                }
                NavigationLink {
                    AudioSettings().navigationTitle("Audio")
                } label: {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #endif
    }
}

private struct ReadingSettings: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Text") {
                LabeledContent("Arabic size") {
                    Slider(value: $settings.arabicFontSize, in: 18...72, step: 2)
                    Text("\(Int(settings.arabicFontSize))").monospacedDigit().frame(width: 28)
                }
                LabeledContent("Translation size") {
                    Slider(value: $settings.translationFontSize, in: 11...32, step: 1)
                    Text("\(Int(settings.translationFontSize))").monospacedDigit().frame(width: 28)
                }
                Picker("Arabic font", selection: $settings.quranFont) {
                    ForEach(QuranFont.allCases) { Text($0.name).tag($0) }
                }
                Picker("Arabic script", selection: $settings.script) {
                    ForEach(ArabicScript.allCases) { Text($0.name).tag($0) }
                }
            }

            Section {
                Toggle("Tajweed colors", isOn: $settings.showsTajweed)
                    .disabled(settings.script != .uthmani)
                if settings.isTajweedActive {
                    DisclosureGroup("Color guide") { TajweedLegend().padding(.vertical, 6) }
                }
            } header: {
                Text("Tajweed")
            } footer: {
                Text("Tajweed colors are available with the Uthmani script.")
                    .foregroundStyle(.secondary)
            }

            Section("Word by Word") {
                Picker("Language", selection: $settings.wordTranslationLanguageCode) {
                    ForEach(WordTranslationLanguage.supported) { Text($0.name).tag($0.code) }
                }
                Toggle("Show word translation", isOn: $settings.showWordTranslation)
                Toggle("Show transliteration", isOn: $settings.showTransliteration)
            }

            Section("Preview") {
                if let sample = Self.sampleWord {
                    WordView(word: sample, arabicFontSize: settings.arabicFontSize)
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                Toggle("Follow recitation while playing", isOn: $settings.autoScroll)
                Toggle("Memorization mode", isOn: $settings.memorizationMode)
            }
        }
        .formStyle(.grouped)
    }

    private static let sampleWord: Word? = try? JSONDecoder().decode(Word.self, from: Data("""
    {"id":1,"position":1,"char_type_name":"word","text":"بِسْمِ","text_uthmani":"بِسْمِ","text_indopak":"بِسۡمِ",
     "text_imlaei":"بِسْمِ","translation":{"text":"In (the) name"},"transliteration":{"text":"bis'mi"}}
    """.utf8))
}

private struct AudioSettings: View {
    @Bindable private var settings = AppSettings.shared
    private let player = RecitationPlayer.shared

    var body: some View {
        Form {
            Section("Recitation") {
                if settings.reciters.isEmpty {
                    LabeledContent("Reciter", value: settings.recitersError ?? "Loading…")
                } else {
                    Picker("Reciter", selection: $settings.selectedReciterId) {
                        ForEach(settings.reciters) { Text($0.displayName).tag($0.id) }
                    }
                }
                Picker("Speed", selection: Binding(get: { settings.playbackRate }, set: { player.setRate($0) })) {
                    ForEach(AudioPlayerBar.rates, id: \.self) { Text(AudioPlayerBar.rateLabel($0)).tag($0) }
                }
            }

            Section("Repeat") {
                Picker("Repeat each verse", selection: $settings.verseRepeatCount) {
                    ForEach(RepeatCount.choices, id: \.self) { Text(RepeatCount.label($0)).tag($0) }
                }
                Picker("Repeat verse range", selection: $settings.rangeRepeatCount) {
                    ForEach(RepeatCount.choices, id: \.self) { Text(RepeatCount.label($0)).tag($0) }
                }
                LabeledContent("Pause between repeats") {
                    Slider(value: $settings.pauseBetweenRepeats, in: 0...5, step: 0.5)
                    Text("\(settings.pauseBetweenRepeats, specifier: "%.1f") s").monospacedDigit().frame(width: 40)
                }
            }

            OfflineSettingsSection()
        }
        .formStyle(.grouped)
    }
}
