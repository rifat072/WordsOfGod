//
//  ChaptersView.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct ChaptersView: View {
    @Bindable private var reader = Reader.shared
    private let player = RecitationPlayer.shared
    @State private var searchText = ""

    var body: some View {
        List(selection: $reader.selectedChapterId) {
            if let jump = verseJump {
                Section {
                    Button {
                        reader.reveal(chapter: jump.chapter.id, verse: jump.verse)
                        searchText = ""
                    } label: {
                        Label("Go to \(jump.chapter.name_simple) \(jump.chapter.id):\(jump.verse)",
                              systemImage: "arrow.turn.down.right")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                ForEach(filteredChapters) { chapter in
                    ChapterRow(chapter: chapter, isPlaying: player.chapter?.id == chapter.id)
                        .tag(chapter.id)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Surah or 2:255")
        .onSubmit(of: .search) {
            if let jump = verseJump {
                reader.reveal(chapter: jump.chapter.id, verse: jump.verse)
                searchText = ""
            } else if let first = filteredChapters.first {
                reader.selectedChapterId = first.id
            }
        }
        .overlay { statusOverlay }
        .navigationTitle("Surahs")
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if reader.chapters.isEmpty {
            if let error = reader.chaptersError {
                ContentUnavailableView {
                    Label("Couldn’t Load Surahs", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { Task { await reader.loadChapters() } }
                }
            } else {
                ProgressView()
            }
        } else if filteredChapters.isEmpty && verseJump == nil {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private var filteredChapters: [Chapter] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return reader.chapters }
        if let number = Int(query) { return reader.chapters.filter { $0.id == number } }
        return reader.chapters.filter { chapter in
            [chapter.name_simple, chapter.name_complex, chapter.name_arabic, chapter.translated_name?.name ?? ""]
                .contains { $0.localizedStandardContains(query) }
        }
    }

    private var verseJump: (chapter: Chapter, verse: Int)? {
        let parts = searchText.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let chapterNumber = Int(parts[0]), let verse = Int(parts[1]),
              let chapter = reader.chapters.first(where: { $0.id == chapterNumber }),
              (1...chapter.verses_count).contains(verse) else { return nil }
        return (chapter, verse)
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(chapter.id)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: .rect(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(chapter.name_simple)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .symbolEffect(.variableColor.iterative, isActive: RecitationPlayer.shared.isActivelyPlaying)
                    }
                }
                HStack(spacing: 4) {
                    if let translated = chapter.translated_name?.name {
                        Text(translated)
                        Text("·")
                    }
                    Text("\(chapter.verses_count) verses")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Text(chapter.name_arabic)
                .font(AppSettings.shared.quranFont.font(size: 18))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .help("\(chapter.name_complex) · \(chapter.revelationPlaceName) · \(chapter.verses_count) verses")
    }
}

#Preview {
    ChaptersView()
}
