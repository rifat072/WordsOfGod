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
        didSet { UserDefaults.standard.set(selectedChapterId, forKey: "lastChapterId") }
    }
    var verseToReveal: Int?
    var isShowingSettings = false

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
