//
//  ChapterStore.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

@MainActor
@Observable
final class ChapterStore {
    let chapter: Chapter

    private(set) var verses: [Verse] = []
    private(set) var isLoadingVerses = false
    private(set) var versesError: String?

    private(set) var audio: ChapterAudio?
    private(set) var audioError: String?

    init(chapter: Chapter) { self.chapter = chapter }

    func loadVerses(translationIds: [Int], wordLanguage: String) async {
        isLoadingVerses = true
        defer { isLoadingVerses = false }
        do {
            verses = try await APIClient.shared.getVerses(chapter: chapter.id,
                                                          translationIds: translationIds,
                                                          wordLanguage: wordLanguage)
            versesError = nil
        } catch {
            guard !Task.isCancelled else { return }
            versesError = error.localizedDescription
        }
    }

    func loadAudio(reciterId: Int) async {
        audio = nil
        do {
            audio = try await APIClient.shared.getChapterAudio(reciterId: reciterId, chapter: chapter.id)
            audioError = nil
        } catch {
            guard !Task.isCancelled else { return }
            audioError = error.localizedDescription
        }
    }

    func verse(_ number: Int) -> Verse? {
        verses.indices.contains(number - 1) ? verses[number - 1] : nil
    }
}
