//
//  AppSettings.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private(set) var reciters: [ChapterReciter] = []
    private(set) var translations: [Translation] = []
    private(set) var tafsirs: [Tafsir] = []
    private(set) var recitersError: String?
    private(set) var translationsError: String?
    private(set) var tafsirsError: String?

    var selectedReciterId: Int = Stored.value(.reciterId, default: 7) {
        didSet {
            Stored.set(selectedReciterId, for: .reciterId)
            RecitationPlayer.shared.stop()
        }
    }
    var selectedTranslationIds: [Int] = AppSettings.initialTranslationIds {
        didSet { Stored.set(selectedTranslationIds, for: .translationIds) }
    }
    var selectedTafsirId: Int = Stored.value(.tafsirId, default: 169) {
        didSet { Stored.set(selectedTafsirId, for: .tafsirId) }
    }
    var wordTranslationLanguageCode: String = AppSettings.initialWordTranslationLanguage {
        didSet { Stored.set(wordTranslationLanguageCode, for: .wordTranslationLanguage) }
    }

    var arabicFontSize: Double = Stored.value(.arabicFontSize, default: 30) {
        didSet { Stored.set(arabicFontSize, for: .arabicFontSize) }
    }
    var translationFontSize: Double = Stored.value(.translationFontSize, default: 15) {
        didSet { Stored.set(translationFontSize, for: .translationFontSize) }
    }
    var script: ArabicScript = ArabicScript(rawValue: Stored.value(.script, default: "")) ?? .uthmani {
        didSet { Stored.set(script.rawValue, for: .script) }
    }
    var quranFont: QuranFont = QuranFont(rawValue: Stored.value(.quranFont, default: "")) ?? .amiriQuran {
        didSet { Stored.set(quranFont.rawValue, for: .quranFont) }
    }
    var showsTajweed: Bool = Stored.value(.showsTajweed, default: true) {
        didSet { Stored.set(showsTajweed, for: .showsTajweed) }
    }
    var isTajweedActive: Bool { showsTajweed && script == .uthmani }
    var showWordTranslation: Bool = Stored.value(.showWordTranslation, default: true) {
        didSet { Stored.set(showWordTranslation, for: .showWordTranslation) }
    }
    var showTransliteration: Bool = Stored.value(.showTransliteration, default: true) {
        didSet { Stored.set(showTransliteration, for: .showTransliteration) }
    }
    var autoScroll: Bool = Stored.value(.autoScroll, default: true) {
        didSet { Stored.set(autoScroll, for: .autoScroll) }
    }
    var memorizationMode: Bool = Stored.value(.memorizationMode, default: false) {
        didSet { Stored.set(memorizationMode, for: .memorizationMode) }
    }

    var savesPlayedSurahs: Bool = Stored.value(.savesPlayedSurahs, default: true) {
        didSet { Stored.set(savesPlayedSurahs, for: .savesPlayedSurahs) }
    }
    var savesOverCellular: Bool = Stored.value(.savesOverCellular, default: false) {
        didSet { Stored.set(savesOverCellular, for: .savesOverCellular) }
    }

    var playbackRate: Float = Stored.value(.playbackRate, default: 1) {
        didSet { Stored.set(playbackRate, for: .playbackRate) }
    }
    var verseRepeatCount: Int = Stored.value(.verseRepeatCount, default: 1) {
        didSet { Stored.set(verseRepeatCount, for: .verseRepeatCount) }
    }
    var rangeRepeatCount: Int = Stored.value(.rangeRepeatCount, default: RepeatCount.infinite) {
        didSet { Stored.set(rangeRepeatCount, for: .rangeRepeatCount) }
    }
    var pauseBetweenRepeats: Double = Stored.value(.pauseBetweenRepeats, default: 0) {
        didSet { Stored.set(pauseBetweenRepeats, for: .pauseBetweenRepeats) }
    }

    var selectedReciter: ChapterReciter? { reciters.first { $0.id == selectedReciterId } }
    var selectedTafsir: Tafsir? { tafsirs.first { $0.id == selectedTafsirId } }

    func isTranslationSelected(_ id: Int) -> Bool { selectedTranslationIds.contains(id) }

    func setTranslation(_ id: Int, selected: Bool) {
        if selected, !isTranslationSelected(id) {
            selectedTranslationIds.append(id)
        } else if !selected {
            selectedTranslationIds.removeAll { $0 == id }
        }
    }

    func adjustFontSizes(by step: Double) {
        arabicFontSize = min(max(arabicFontSize + step * 2, 18), 72)
        translationFontSize = min(max(translationFontSize + step, 11), 32)
    }

    func load() async {
        async let reciters = APIClient.shared.getChapterReciters()
        async let translations = APIClient.shared.getTranslationList()
        async let tafsirs = APIClient.shared.getTafsirList()

        do {
            self.reciters = try await reciters
            recitersError = nil
            if !self.reciters.isEmpty, selectedReciter == nil {
                selectedReciterId = self.reciters[0].id
            }
        } catch {
            recitersError = error.localizedDescription
        }

        do {
            self.translations = try await translations
            translationsError = nil
        } catch {
            translationsError = error.localizedDescription
        }

        do {
            self.tafsirs = try await tafsirs
            tafsirsError = nil
        } catch {
            tafsirsError = error.localizedDescription
        }
    }

    private static var initialWordTranslationLanguage: String {
        let stored: String = Stored.value(.wordTranslationLanguage, default: "en")
        return WordTranslationLanguage.supported.contains { $0.code == stored } ? stored : "en"
    }

    private static var initialTranslationIds: [Int] {
        if let ids = UserDefaults.standard.array(forKey: Stored.Key.translationIds.rawValue) as? [Int] {
            return ids
        }
        if let legacyId = UserDefaults.standard.object(forKey: Stored.Key.legacyTranslationId.rawValue) as? Int {
            return [legacyId]
        }
        return [20]
    }
}

enum RepeatCount {
    static let infinite = Int.max
    static let choices = [1, 2, 3, 5, 10, infinite]

    static func label(_ count: Int) -> String {
        count == infinite ? "∞" : "\(count)×"
    }
}

private enum Stored {
    enum Key: String {
        case reciterId = "chapterReciterId"
        case translationIds, legacyTranslationId = "translationId", tafsirId
        case wordTranslationLanguage, arabicFontSize, translationFontSize, script, quranFont, showsTajweed
        case showWordTranslation, showTransliteration, autoScroll, memorizationMode
        case savesPlayedSurahs, savesOverCellular
        case playbackRate, verseRepeatCount, rangeRepeatCount, pauseBetweenRepeats
    }

    static func value<T>(_ key: Key, default defaultValue: T) -> T {
        UserDefaults.standard.object(forKey: key.rawValue) as? T ?? defaultValue
    }

    static func set(_ value: Any, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
