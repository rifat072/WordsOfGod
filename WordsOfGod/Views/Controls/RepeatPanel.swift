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
    @FocusState private var editingBound: VerseNumberField.Bound?

    private var verseCount: Int { chapter.verses_count }
    private var hasActiveRange: Bool { player.hasRange && player.chapter?.id == chapter.id }

    var body: some View {
        #if os(macOS)
        form
        #else
        NavigationStack {
            form
                .navigationTitle("Repeat")
                .navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }

    private var form: some View {
        Form {
            Section("Each Verse") {
                RepeatCountPicker(title: "Repeat", selection: $settings.verseRepeatCount)
            }

            Section("Verse Range") {
                VerseNumberField(bound: .start, verse: $startVerse, range: 1...verseCount, focus: $editingBound)
                VerseNumberField(bound: .end, verse: $endVerse, range: startVerse...verseCount, focus: $editingBound)
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editingBound = nil }
            }
        }
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
        editingBound = nil
        guard let audio else { return }
        player.play(chapter: chapter, audio: audio, fromVerse: startVerse)
        player.setRange(from: startVerse, to: endVerse)
    }
}

private struct VerseNumberField: View {
    enum Bound { case start, end }

    let bound: Bound
    @Binding var verse: Int
    let range: ClosedRange<Int>
    var focus: FocusState<Bound?>.Binding
    @State private var text = ""

    private var title: String { bound == .start ? "From verse" : "To verse" }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                TextField(title, text: $text)
                    .labelsHidden()
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                    #if !os(macOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused(focus, equals: bound)
                    .onSubmit(showVerse)
                Stepper(title, value: $verse, in: range)
                    .labelsHidden()
            }
        }
        .onAppear(perform: showVerse)
        // Partial input such as "2" on the way to "255" is kept as typed; only in-range numbers are applied.
        .onChange(of: text) {
            if let number = Int(text), range.contains(number) { verse = number }
        }
        .onChange(of: verse) { if Int(text) != verse { showVerse() } }
        .onChange(of: focus.wrappedValue) { if focus.wrappedValue != bound { showVerse() } }
    }

    private func showVerse() { text = String(verse) }
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
