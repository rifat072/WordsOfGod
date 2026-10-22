//
//  Reader.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

@MainActor
@Observable
final class Reader {
    static let shared = Reader()

    private(set) var chapters: [Chapter] = []
    private(set) var chaptersError: String?
    private(set) var isLoadingChapters = false

    var selectedChapterId: Int? = UserDefaults.standard.object(forKey: "lastChapterId") as? Int {
        didSet {
            UserDefaults.standard.set(selectedChapterId, forKey: "lastChapterId")
            if selectedChapterId != oldValue { tafsirVerseKey = nil }
        }
    }
    var verseToReveal: Int?
    var tafsirVerseKey: String?
    var isShowingSettings = false

    @ObservationIgnored
    private var readingPositions = UserDefaults.standard.dictionary(forKey: "readingPositions") as? [String: Int] ?? [:] {
        didSet { UserDefaults.standard.set(readingPositions, forKey: "readingPositions") }
    }

    var selectedChapter: Chapter? { chapters.first { $0.id == selectedChapterId } }

    func loadChapters() async {
        guard chapters.isEmpty, !isLoadingChapters else { return }
        isLoadingChapters = true
        defer { isLoadingChapters = false }
        do {
            chapters = try await APIClient.shared.getChapters()
            chaptersError = nil
        } catch {
            chaptersError = error.localizedDescription
        }
    }

    func reveal(chapter: Int, verse: Int? = nil) {
        selectedChapterId = chapter
        verseToReveal = verse
    }

    func readingPosition(in chapter: Int) -> Int? {
        readingPositions[String(chapter)]
    }

    func saveReadingPosition(_ verse: Int, in chapter: Int) {
        readingPositions[String(chapter)] = verse > 1 ? verse : nil
    }

    func showPlayingChapter() {
        guard let playing = RecitationPlayer.shared.chapter else { return }
        if selectedChapterId != playing.id { selectedChapterId = playing.id }
    }

    func togglePresentation() {
        let player = RecitationPlayer.shared
        guard player.isLoaded else { return }
        showPlayingChapter()
        player.isPresentationVisible.toggle()
    }
}
