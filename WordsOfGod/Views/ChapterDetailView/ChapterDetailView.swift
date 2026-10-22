//
//  ChapterDetailView.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct ChapterDetailView: View {
    let chapter: Chapter
    @State private var store: ChapterStore
    @State private var isShowingTranslations = false
    @State private var isShowingRepeat = false
    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    @State private var resumeVerse: Int?
    @State private var topVerse = 1
    @Bindable private var reader = Reader.shared
    private let player = RecitationPlayer.shared
    private let settings = AppSettings.shared

    init(chapter: Chapter) {
        self.chapter = chapter
        _store = State(initialValue: ChapterStore(chapter: chapter))
        _resumeVerse = State(initialValue: Reader.shared.readingPosition(in: chapter.id))
    }

    private var isPlayerOnThisChapter: Bool { player.chapter?.id == chapter.id }
    private var verseRequestKey: String {
        "\(settings.selectedTranslationIds):\(settings.wordTranslationLanguageCode)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ChapterHeader(chapter: chapter, audioError: store.audioError, audioURL: store.audio?.url)
                    .padding(.bottom, 8)

                if store.verses.isEmpty {
                    versesPlaceholder
                }

                LazyVStack(spacing: 4) {
                    ForEach(store.verses, id: \.verse_number) { verse in
                        VerseView(verse: verse)
                    }
                }
                .scrollTargetLayout()
            }
            .padding(.horizontal, Spacing.readerMargin)
            .padding(.vertical, 20)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($scrollPosition, anchor: .top)
        .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.1) { visibleVerses in
            guard let top = visibleVerses.min() else { return }
            topVerse = top
            reader.saveReadingPosition(top, in: chapter.id)
        }
        .environment(store)
        .onChange(of: player.currentVerse) { followRecitation() }
        .onChange(of: player.isActivelyPlaying) { followRecitation() }
        .onChange(of: reader.verseToReveal, initial: true) { revealPendingVerse() }
        .onChange(of: store.verses.count) { revealPendingVerse() }
        .overlay {
            if player.isPresentationVisible, isPlayerOnThisChapter {
                PresentationView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: player.isPresentationVisible)
        .inspector(isPresented: isShowingTafsir) {
            if let verseKey = reader.tafsirVerseKey {
                TafsirView(verseKey: verseKey)
                    .inspectorColumnWidth(min: 300, ideal: 380, max: 560)
                    .presentationDetents([.medium, .large])
            }
        }
        .task(id: verseRequestKey) {
            await store.loadVerses(translationIds: settings.selectedTranslationIds,
                                   wordLanguage: settings.wordTranslationLanguageCode)
        }
        .task(id: settings.selectedReciterId) {
            await store.loadAudio(reciterId: settings.selectedReciterId)
        }
        .navigationTitle(chapter.name_simple)
        .navigationSubtitle(subtitle)
        .toolbar { toolbarContent }
    }

    private var isShowingTafsir: Binding<Bool> {
        Binding(get: { reader.tafsirVerseKey != nil },
                set: { if !$0 { reader.tafsirVerseKey = nil } })
    }

    private var subtitle: String {
        [chapter.translated_name?.name, chapter.revelationPlaceName, "\(chapter.verses_count) verses"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var versesPlaceholder: some View {
        if let error = store.versesError {
            ContentUnavailableView {
                Label("Couldn’t Load Verses", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") {
                    Task {
                        await store.loadVerses(translationIds: settings.selectedTranslationIds,
                                               wordLanguage: settings.wordTranslationLanguageCode)
                    }
                }
            }
        } else {
            ProgressView().padding(40)
        }
    }

    private func followRecitation() {
        guard settings.autoScroll, isPlayerOnThisChapter, player.isActivelyPlaying, let verse = player.currentVerse else { return }
        withAnimation(.easeInOut(duration: 0.4)) { scrollPosition.scrollTo(id: verse, anchor: .top) }
    }

    private func revealPendingVerse() {
        guard let verse = reader.verseToReveal ?? resumeVerse, store.verse(verse) != nil else { return }
        reader.verseToReveal = nil
        resumeVerse = nil
        Task { scrollPosition.scrollTo(id: verse, anchor: .top) }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                togglePlayback()
            } label: {
                Label(isPlayerOnThisChapter && player.isActivelyPlaying ? "Pause" : "Play",
                      systemImage: isPlayerOnThisChapter && player.isActivelyPlaying ? "pause.fill" : "play.fill")
            }
            .disabled(store.audio == nil)
            .help(store.audio == nil ? (store.audioError ?? "Loading recitation…") : "Play or pause the recitation")

            Button {
                isShowingRepeat.toggle()
            } label: {
                Label("Repeat", systemImage: player.hasRange && isPlayerOnThisChapter ? "repeat.circle.fill" : "repeat")
            }
            .help("Repeat and memorization")
            .popover(isPresented: $isShowingRepeat, arrowEdge: .bottom) {
                RepeatPanel(chapter: chapter, audio: store.audio)
            }

            Button {
                reader.togglePresentation()
            } label: {
                Label("Presentation", systemImage: "rectangle.expand.vertical")
            }
            .disabled(!isPlayerOnThisChapter)
            .help("Show the playing verse in large view (⇧⌘P)")
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            Button {
                reader.tafsirVerseKey = reader.tafsirVerseKey == nil ? "\(chapter.id):\(topVerse)" : nil
            } label: {
                Label("Tafsir", systemImage: "text.book.closed")
            }
            .help("Commentary on the verse at the top of the page")

            OfflineDownloadButton(audioURL: store.audio?.url)

            Button {
                isShowingTranslations.toggle()
            } label: {
                Label("Translations", systemImage: "character.book.closed")
            }
            .help("Choose translations")
            .popover(isPresented: $isShowingTranslations, arrowEdge: .bottom) {
                TranslationPicker()
                    .frame(minWidth: 320, idealWidth: 360, minHeight: 440, idealHeight: 520)
                    .presentationDetents([.large])
            }

            DisplayMenu()
        }
    }

    private func togglePlayback() {
        if isPlayerOnThisChapter {
            player.toggle()
        } else if let audio = store.audio {
            player.play(chapter: chapter, audio: audio, fromVerse: 1)
        }
    }
}

private struct ChapterHeader: View {
    let chapter: Chapter
    let audioError: String?
    let audioURL: URL?

    var body: some View {
        VStack(spacing: 10) {
            Text(chapter.name_arabic)
                .font(AppSettings.shared.quranFont.font(size: 48))
            Text("\(chapter.name_complex) · \(chapter.translated_name?.name ?? "")")
                .font(.title3)
                .foregroundStyle(.secondary)

            FlowLayout(hSpacing: 12, vSpacing: 6, centersRows: true) {
                Label(chapter.revelationPlaceName, systemImage: chapter.isMakki ? "building.columns" : "house")
                Label("\(chapter.verses_count) verses", systemImage: "text.alignright")
                Label("Revelation order \(chapter.revelation_order)", systemImage: "number")
            }
            .padding(.horizontal)
            .font(.caption)
            .foregroundStyle(.secondary)

            if chapter.bismillah_pre {
                Image(.bismillah)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 44)
                    .padding(.top, 10)
            }

            if AppSettings.shared.isTajweedActive {
                TajweedLegendButton()
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            OfflineStatusBadge(audioURL: audioURL)
                .font(.caption)

            if let audioError {
                Label(audioError, systemImage: "speaker.slash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.background.secondary, in: .rect(cornerRadius: 18, style: .continuous))
    }
}
