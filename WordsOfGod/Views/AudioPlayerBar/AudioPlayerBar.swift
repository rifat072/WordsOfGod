//
//  AudioPlayerBar.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct AudioPlayerBar: View {
    private let player = RecitationPlayer.shared
    private let settings = AppSettings.shared
    private let reader = Reader.shared
    @State private var scrubValue: Double = 0
    @State private var isScrubbing = false
    @State private var isShowingRepeat = false

    static let rates: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                nowPlayingTitle
                Spacer()
                if let progress = player.repeatProgress {
                    Label(progress, systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                }
                if let error = player.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    transportControls
                    scrubber.frame(minWidth: 180)
                    trailingControls
                }
                VStack(spacing: 6) {
                    scrubber
                    HStack {
                        transportControls
                        Spacer()
                        trailingControls
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var nowPlayingTitle: some View {
        Button {
            reader.showPlayingChapter()
            reader.verseToReveal = player.currentVerse
        } label: {
            HStack(spacing: 6) {
                Text(player.chapter?.name_simple ?? "")
                    .font(.headline)
                if let chapter = player.chapter, let verse = player.currentVerse {
                    Text("\(chapter.id):\(verse)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                if let reciter = settings.selectedReciter?.name {
                    Text("· \(reciter)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Show the playing verse")
        .animation(.default, value: player.currentVerse)
    }

    private var transportControls: some View {
        HStack(spacing: 10) {
            Button("Previous Verse", systemImage: "backward.end.fill") { player.previousVerse() }
            Button(player.isActivelyPlaying ? "Pause" : "Play",
                   systemImage: player.isActivelyPlaying ? "pause.circle.fill" : "play.circle.fill") {
                player.toggle()
            }
            .font(.system(size: 30))
            .contentTransition(.symbolEffect(.replace))
            Button("Next Verse", systemImage: "forward.end.fill") { player.nextVerse() }
                .disabled(!player.canGoToNextVerse)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .imageScale(.large)
    }

    private var scrubber: some View {
        HStack(spacing: 8) {
            Text(format(isScrubbing ? scrubValue : player.currentTime))
                .frame(minWidth: 44, alignment: .trailing)
                .fixedSize()

            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : min(player.currentTime, max(player.duration, 1)) },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(player.duration, 1)
            ) { editing in
                if editing {
                    scrubValue = player.currentTime
                    isScrubbing = true
                } else {
                    player.seek(to: scrubValue)
                    isScrubbing = false
                }
            }
            .controlSize(.small)
            .disabled(player.duration == 0)

            Text(format(player.duration))
                .frame(minWidth: 44, alignment: .leading)
                .fixedSize()
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var trailingControls: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Speed", selection: Binding(get: { settings.playbackRate }, set: { player.setRate($0) })) {
                    ForEach(Self.rates, id: \.self) { Text(Self.rateLabel($0)).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Text(Self.rateLabel(settings.playbackRate))
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            #if os(macOS)
            .menuStyle(.button)
            #endif
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Playback speed")

            Button("Repeat", systemImage: player.hasRange ? "repeat.circle.fill" : "repeat") {
                isShowingRepeat.toggle()
            }
            .popover(isPresented: $isShowingRepeat, arrowEdge: .top) {
                if let chapter = player.chapter {
                    RepeatPanel(chapter: chapter, audio: player.audio)
                }
            }
            .help("Repeat and memorization")

            Button("Presentation", systemImage: "rectangle.expand.vertical") { reader.togglePresentation() }
                .help("Large view (⇧⌘P)")

            Button("Stop", systemImage: "xmark") { player.stop() }
                .help("Stop and close the player")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    static func rateLabel(_ rate: Float) -> String {
        rate.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
