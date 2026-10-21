//
//  QuranFont.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI
import CoreText

enum QuranFont: String, CaseIterable, Identifiable {
    case amiriQuran, scheherazade, system

    var id: String { rawValue }

    var name: String {
        switch self {
        case .amiriQuran: "Amiri Quran"
        case .scheherazade: "Scheherazade New"
        case .system: "System (Geeza Pro)"
        }
    }

    var drawsOrnateAyahMarker: Bool { self != .system }

    private var visualSizeScale: Double {
        switch self {
        case .amiriQuran: 1.25
        case .scheherazade: 1.12
        case .system: 1
        }
    }

    func font(size: Double) -> Font {
        switch self {
        case .system: .system(size: size)
        default: .custom(name, fixedSize: size * visualSizeScale)
        }
    }

    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}
