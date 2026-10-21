//
//  PresentationView.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct PresentationView: View {
    let store: ChapterStore
    private let player = RecitationPlayer.shared
    private let settings = AppSettings.shared
    @State private var shownVerse: Int
    @State private var slideEdge: Edge = .trailing

    init(store: ChapterStore) {
        self.store = store
        _shownVerse = State(initialValue: RecitationPlayer.shared.currentVerse ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            carousel
            bottomBar
        }
        .background {
            ZStack {
                Rectangle().fill(.background)
                LinearGradient(colors: [Color.accentColor.opacity(0.10), .clear],
                               startPoint: .top, endPoint: .center)
            }
            .ignoresSafeArea()
        }
        .onChange(of: player.currentVerse) { _, verse in
            guard let verse, verse != shownVerse else { return }
            slideEdge = verse > shownVerse ? .trailing : .leading
            withAnimation(.smooth(duration: 0.45)) { shownVerse = verse }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.chapter.name_simple)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    Text(store.chapter.name_arabic)
                        .font(settings.quranFont.font(size: 17))
                    Text("· \(store.chapter.translated_name?.name ?? "")")
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close", systemImage: "xmark") { player.isPresentationVisible = false }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.title2)
                .keyboardShortcut(.cancelAction)
                .help("Close (Esc)")
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }

    private var carousel: some View {
        ZStack {
            if let verse = store.verse(shownVerse) {
                PresentationSlide(verse: verse, isCurrent: player.currentVerse == verse.verse_number)
                    .id(verse.verse_number)
                    .transition(.push(from: slideEdge))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(.rect)
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded(swipeToNeighbourVerse))
    }

    private func swipeToNeighbourVerse(_ swipe: DragGesture.Value) {
        let horizontal = swipe.translation.width
        guard abs(horizontal) > 60, abs(horizontal) > abs(swipe.translation.height) else { return }
        horizontal < 0 ? player.nextVerse() : player.previousVerse()
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Text("\(store.chapter.id):\(shownVerse)")
                .font(.headline.monospacedDigit())
            Text("\(shownVerse) / \(store.chapter.verses_count)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            if let progress = player.repeatProgress {
                Label(progress, systemImage: "repeat")
                    .font(.callout)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

private struct PresentationSlide: View {
    let verse: Verse
    let isCurrent: Bool
    private let settings = AppSettings.shared
    private let player = RecitationPlayer.shared
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var scale: Double { sizeClass == .compact ? 1.2 : 1.8 }
    #else
    private let scale = 1.8
    #endif

    var body: some View {
        ScrollViewReader { proxy in
            slideContent
                .onChange(of: isCurrent ? player.currentWord : nil) { _, position in
                    guard let word = verse.words.first(where: { $0.position == position }) else { return }
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(word.id, anchor: .center) }
                }
        }
    }

    private var slideContent: some View {
        ScrollView {
            VStack(spacing: 36) {
                VerseWordsView(verse: verse,
                               isCurrentVerse: isCurrent,
                               revealsAll: !settings.memorizationMode,
                               arabicFontSize: settings.arabicFontSize * scale,
                               spacing: 10,
                               centersRows: true)
                    .frame(maxWidth: .infinity, alignment: .center)

                VerseTranslationsView(verse: verse,
                                      fontSize: settings.translationFontSize * (1 + (scale - 1) * 0.6),
                                      alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 1100)
            .padding(.horizontal)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollIndicators(.automatic)
    }
}
