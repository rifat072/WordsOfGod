//
//  RepeatPanel.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct RepeatPanel: View {
    let chapter: Chapter
    let audio: ChapterAudio?
    @Bindable private var settings = AppSettings.shared
    private let player = RecitationPlayer.shared
    @State private var startVerse = 1
    @State private var endVerse = 1

    private var verseCount: Int { chapter.verses_count }
    private var hasActiveRange: Bool { player.hasRange && player.chapter?.id == chapter.id }

    var body: some View {
        Form {
            Section("Each Verse") {
                RepeatCountPicker(title: "Repeat", selection: $settings.verseRepeatCount)
            }

            Section("Verse Range") {
                HStack {
                    Stepper("From \(startVerse)", value: $startVerse, in: 1...verseCount)
                    Spacer()
                    Stepper("To \(endVerse)", value: $endVerse, in: startVerse...verseCount)
                }
                RepeatCountPicker(title: "Repeat range", selection: $settings.rangeRepeatCount)

                HStack {
                    if hasActiveRange {
                        Button("Clear Range", role: .destructive) { player.clearRange() }
                    }
                    Spacer()
                    Button(hasActiveRange ? "Update & Play" : "Play Range") { playRange() }
                        .buttonStyle(.borderedProminent)
                        .disabled(audio == nil)
                }
            }

            Section("Pause Between Repeats") {
                Slider(value: $settings.pauseBetweenRepeats, in: 0...5, step: 0.5) {
                    Text(settings.pauseBetweenRepeats == 0 ? "None" : "\(settings.pauseBetweenRepeats, specifier: "%.1f") s")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .leading)
                }
            }

            Section {
                Toggle("Memorization mode", isOn: $settings.memorizationMode)
            } footer: {
                Text("Blurs the Arabic text until it is recited. Hover over a verse to reveal it.")
                    .foregroundStyle(.secondary)
            }

            if let progress = player.repeatProgress, player.chapter?.id == chapter.id {
                Label(progress, systemImage: "repeat")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        #else
        .frame(minWidth: 340, idealWidth: 380, minHeight: 560)
        .presentationDetents([.medium, .large])
        #endif
        .onAppear(perform: loadInitialRange)
        .onChange(of: startVerse) { endVerse = max(endVerse, startVerse) }
    }

    private func loadInitialRange() {
        if hasActiveRange, let start = player.rangeStart, let end = player.rangeEnd {
            startVerse = start
            endVerse = end
        } else {
            startVerse = player.chapter?.id == chapter.id ? (player.currentVerse ?? 1) : 1
            endVerse = min(startVerse + 4, verseCount)
        }
    }

    private func playRange() {
        guard let audio else { return }
        player.play(chapter: chapter, audio: audio, fromVerse: startVerse)
        player.setRange(from: startVerse, to: endVerse)
    }
}

struct RepeatCountPicker: View {
    let title: String
    @Binding var selection: Int

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(RepeatCount.choices, id: \.self) { count in
                Text(RepeatCount.label(count)).tag(count)
            }
        }
        .pickerStyle(.segmented)
    }
}
