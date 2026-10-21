//
//  Models.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import Foundation

struct Chapter: Decodable, Identifiable, Hashable {
    let id: Int
    let revelation_place: String
    let revelation_order: Int
    let bismillah_pre: Bool
    let name_complex: String
    let name_arabic: String
    let verses_count: Int
    let pages: [Int]
    let name_simple: String
    let translated_name: TranslatedName?

    struct TranslatedName: Decodable, Hashable {
        let name: String
    }

    var isMakki: Bool { revelation_place.lowercased() == "makkah" }
    var revelationPlaceName: String { isMakki ? "Makki" : "Madani" }
}
struct ChaptersResponse: Decodable { let chapters: [Chapter] }

struct Verse: Decodable, Identifiable {
    let id: Int
    let verse_number: Int
    let verse_key: String
    let words: [Word]
    let translations: [VerseTranslation]?

    var recitedWords: [Word] { words.filter { !$0.isVerseEndMarker } }
}

struct VersesPage: Decodable {
    let verses: [Verse]
    let pagination: Pagination

    struct Pagination: Decodable {
        let next_page: Int?
    }
}

struct VerseTranslation: Decodable, Identifiable {
    let resource_id: Int
    let resource_name: String?
    let text: String

    var id: Int { resource_id }

    var plainText: String {
        text.replacing(/<sup[^>]*>.*?<\/sup>/, with: "")
            .replacing(/<[^>]+>/, with: "")
    }
}

enum ArabicScript: String, CaseIterable, Identifiable {
    case uthmani, indopak, imlaei

    var id: String { rawValue }

    var name: String {
        switch self {
        case .uthmani: "Uthmani"
        case .indopak: "IndoPak"
        case .imlaei: "Imlaei (Simple)"
        }
    }
}

struct Word: Decodable, Identifiable {
    let id: Int
    let position: Int
    let char_type_name: String?
    let text: String
    let text_uthmani: String?
    let text_uthmani_tajweed: String?
    let text_indopak: String?
    let text_imlaei: String?
    let audio_url: String?
    let translation: Gloss?
    let transliteration: Gloss?

    struct Gloss: Decodable {
        let text: String?
    }

    var isVerseEndMarker: Bool { char_type_name == "end" }

    func text(in script: ArabicScript) -> String {
        let scripted = switch script {
        case .uthmani: text_uthmani
        case .indopak: text_indopak
        case .imlaei: text_imlaei
        }
        return (scripted ?? text).withoutPrivateUseCharacters
    }

    var tajweedText: AttributedString? {
        text_uthmani_tajweed.map(TajweedText.attributed)
    }
}

private extension String {
    // IndoPak text carries pause marks in the Private Use Area that only Quran.com's own font can draw.
    var withoutPrivateUseCharacters: String {
        String(String.UnicodeScalarView(unicodeScalars.filter { !(0xE000...0xF8FF).contains($0.value) }))
    }
}

struct ChapterReciter: Decodable, Identifiable {
    let id: Int
    let name: String
    let style: Style?

    struct Style: Decodable {
        let name: String
    }

    var displayName: String {
        guard let style = style?.name, !style.isEmpty else { return name }
        return "\(name) (\(style))"
    }
}
struct ChapterRecitersResponse: Decodable { let reciters: [ChapterReciter] }

struct ChapterAudio: Decodable {
    let audio_url: String
    let timestamps: [VerseTiming]

    private enum CodingKeys: String, CodingKey { case audio_url, timestamps }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        audio_url = try container.decode(String.self, forKey: .audio_url)
        let raw = try container.decodeIfPresent([VerseTiming].self, forKey: .timestamps) ?? []
        timestamps = Self.startingVersesAtTheirFirstWord(raw)
    }

    // A verse's first word often begins a few ms before its timestamp_from; starting there avoids clipping it.
    private static func startingVersesAtTheirFirstWord(_ timings: [VerseTiming]) -> [VerseTiming] {
        var result = timings.map { $0.with(start: min($0.start, $0.words.first?.start ?? $0.start)) }
        for index in result.indices.dropLast() {
            result[index] = result[index].with(end: min(result[index].end, result[index + 1].start))
        }
        return result
    }

    var url: URL? { URL(string: audio_url) }

    func timing(forVerse verseNumber: Int) -> VerseTiming? {
        timestamps.indices.contains(verseNumber - 1) && timestamps[verseNumber - 1].verseNumber == verseNumber
            ? timestamps[verseNumber - 1]
            : timestamps.first { $0.verseNumber == verseNumber }
    }

    func verseTiming(at time: TimeInterval) -> VerseTiming? {
        var low = 0, high = timestamps.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let timing = timestamps[mid]
            if time < timing.start { high = mid - 1 }
            else if time >= timing.end { low = mid + 1 }
            else { return timing }
        }
        return nil
    }
}
struct ChapterAudioResponse: Decodable { let audio_file: ChapterAudio }

struct VerseTiming: Decodable {
    let verseNumber: Int
    let start: TimeInterval
    let end: TimeInterval
    let words: [WordTiming]

    private init(verseNumber: Int, start: TimeInterval, end: TimeInterval, words: [WordTiming]) {
        self.verseNumber = verseNumber
        self.start = start
        self.end = end
        self.words = words
    }

    func with(start: TimeInterval? = nil, end: TimeInterval? = nil) -> VerseTiming {
        VerseTiming(verseNumber: verseNumber, start: start ?? self.start, end: end ?? self.end, words: words)
    }

    struct WordTiming {
        let position: Int
        let start: TimeInterval
        let end: TimeInterval
    }

    private enum CodingKeys: String, CodingKey {
        case verse_key, timestamp_from, timestamp_to, segments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let verseKey = try container.decode(String.self, forKey: .verse_key)
        verseNumber = Int(verseKey.split(separator: ":").last ?? "") ?? 0
        start = try container.decode(Double.self, forKey: .timestamp_from) / 1000
        end = try container.decode(Double.self, forKey: .timestamp_to) / 1000
        // Each segment is [word_position, start_ms, end_ms]; malformed rows are skipped.
        let segments = (try? container.decodeIfPresent([[Double]].self, forKey: .segments)) ?? []
        words = segments.compactMap { segment in
            guard segment.count >= 3 else { return nil }
            return WordTiming(position: Int(segment[0]),
                              start: segment[segment.count - 2] / 1000,
                              end: segment[segment.count - 1] / 1000)
        }
    }

    func wordPosition(at time: TimeInterval) -> Int? {
        words.last { $0.start <= time }?.position
    }

    func timing(forWord position: Int) -> WordTiming? {
        words.first { $0.position == position }
    }
}

struct Translation: Decodable, Identifiable {
    let id: Int
    let name: String
    let author_name: String
    let language_name: String
}
struct TranslationListResponse: Decodable { let translations: [Translation] }

struct WordTranslationLanguage: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    static let supported = [
        WordTranslationLanguage(code: "en", name: "English"),
        WordTranslationLanguage(code: "ar", name: "Arabic"),
        WordTranslationLanguage(code: "bn", name: "Bengali"),
        WordTranslationLanguage(code: "ur", name: "Urdu"),
        WordTranslationLanguage(code: "id", name: "Indonesian"),
        WordTranslationLanguage(code: "tr", name: "Turkish"),
        WordTranslationLanguage(code: "fr", name: "French"),
        WordTranslationLanguage(code: "es", name: "Spanish"),
        WordTranslationLanguage(code: "ru", name: "Russian"),
        WordTranslationLanguage(code: "fa", name: "Persian")
    ]
}
