//
//  VerseView.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct VerseView: View {
    let verse: Verse
    @Environment(ChapterStore.self) private var store
    private let player = RecitationPlayer.shared
    private let settings = AppSettings.shared
    @State private var isHovering = false
    @State private var isRevealed = false

    private var isPlayerOnThisChapter: Bool { player.chapter?.id == store.chapter.id }
    private var isCurrent: Bool { isPlayerOnThisChapter && player.currentVerse == verse.verse_number }
    private var isInLoopRange: Bool {
        guard isPlayerOnThisChapter, let start = player.rangeStart, let end = player.rangeEnd else { return false }
        return (start...end).contains(verse.verse_number)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VerseWordsView(verse: verse,
                           isCurrentVerse: isCurrent,
                           revealsAll: !settings.memorizationMode || isHovering || isRevealed)

            VerseTranslationsView(verse: verse, fontSize: settings.translationFontSize)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, Spacing.verseInset)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.07) : .clear)
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .contextMenu { VerseActions(verse: verse, store: store) }
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(verse.verse_key)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .capsule)
                .onTapGesture { if settings.memorizationMode { isRevealed.toggle() } }
                .help(settings.memorizationMode ? "Tap to reveal or hide this verse" : "")

            if isInLoopRange {
                Image(systemName: "repeat")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .help("In the repeat range")
            }

            Spacer()

            #if os(macOS)
            HStack(spacing: 2) {
                VerseActions(verse: verse, store: store)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .opacity(isHovering || isCurrent ? 1 : 0)
            #else
            Menu {
                VerseActions(verse: verse, store: store)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 32)
            }
            .accessibilityLabel("Verse actions")
            #endif
        }
    }
}

struct VerseWordsView: View {
    let verse: Verse
    let isCurrentVerse: Bool
    var revealsAll = true
    var arabicFontSize: Double = AppSettings.shared.arabicFontSize
    var spacing: CGFloat = 4
    var centersRows = false
    private let player = RecitationPlayer.shared

    var body: some View {
        let activeWord = isCurrentVerse ? player.currentWord : nil
        let pronouncing = player.pronouncingWord

        FlowLayout(hSpacing: spacing, vSpacing: spacing * 2, centersRows: centersRows) {
            ForEach(verse.words) { word in
                WordView(word: word,
                         phase: phase(of: word, activeWord: activeWord),
                         isHidden: !revealsAll && !(activeWord.map { word.position <= $0 } ?? false),
                         isPronouncing: pronouncing == .init(verse: verse.verse_number, position: word.position),
                         arabicFontSize: arabicFontSize)
                .id(word.id)
                .onTapGesture { player.pronounce(word, inVerse: verse.verse_number) }
                .help(word.translation?.text ?? "")
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity, alignment: centersRows ? .center : .trailing)
    }

    private func phase(of word: Word, activeWord: Int?) -> WordView.Phase {
        guard isCurrentVerse, let activeWord else { return .idle }
        if word.position == activeWord { return .current }
        return word.position < activeWord ? .recited : .upcoming
    }
}

struct VerseTranslationsView: View {
    let verse: Verse
    let fontSize: Double
    var alignment: HorizontalAlignment = .leading
    private let settings = AppSettings.shared

    var body: some View {
        let translations = orderedTranslations
        if !translations.isEmpty {
            VStack(alignment: alignment, spacing: 12) {
                ForEach(translations) { translation in
                    VStack(alignment: alignment, spacing: 3) {
                        if translations.count > 1, let name = translation.resource_name {
                            Text(name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(translation.plainText)
                            .font(.system(size: fontSize))
                            .lineSpacing(fontSize * 0.25)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
                }
            }
        }
    }

    private var orderedTranslations: [VerseTranslation] {
        let order = settings.selectedTranslationIds
        return (verse.translations ?? []).sorted {
            (order.firstIndex(of: $0.resource_id) ?? .max) < (order.firstIndex(of: $1.resource_id) ?? .max)
        }
    }
}

struct VerseActions: View {
    let verse: Verse
    let store: ChapterStore
    private let player = RecitationPlayer.shared

    var body: some View {
        Button("Play from Here", systemImage: "play.fill") {
            guard let audio = store.audio else { return }
            player.play(chapter: store.chapter, audio: audio, fromVerse: verse.verse_number)
        }
        .disabled(store.audio == nil)

        Button("Loop This Verse", systemImage: "repeat.1") {
            guard let audio = store.audio else { return }
            player.play(chapter: store.chapter, audio: audio, fromVerse: verse.verse_number)
            player.setRange(from: verse.verse_number, to: verse.verse_number)
        }
        .disabled(store.audio == nil)

        Button("Copy", systemImage: "doc.on.doc") {
            Clipboard.copy(shareText)
        }

        ShareLink(item: shareText) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private var shareText: String {
        let arabic = verse.words.map { $0.text(in: AppSettings.shared.script) }.joined(separator: " ")
        let translations = (verse.translations ?? []).map(\.plainText)
        let reference = "— \(store.chapter.name_simple) \(verse.verse_key)"
        return ([arabic] + translations + [reference]).joined(separator: "\n\n")
    }
}
