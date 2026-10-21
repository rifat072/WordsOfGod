//
//  WordView.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct WordView: View {
    enum Phase {
        case idle, recited, current, upcoming
    }

    let word: Word
    var phase: Phase = .idle
    var isHidden = false
    var isPronouncing = false
    var arabicFontSize: Double = AppSettings.shared.arabicFontSize
    var showsGlosses = true

    private let settings = AppSettings.shared

    var body: some View {
        if word.isVerseEndMarker {
            VerseEndMarker(number: word.text(in: settings.script), font: settings.quranFont, fontSize: arabicFontSize)
        } else {
            wordStack
        }
    }

    private var wordStack: some View {
        VStack(spacing: 4) {
            arabicText
                .font(settings.quranFont.font(size: arabicFontSize))
                .foregroundStyle(phase == .current ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))

            if showsGlosses, settings.showTransliteration, let transliteration = word.transliteration?.text {
                Text(transliteration)
                    .font(.system(size: glossFontSize).italic())
                    .foregroundStyle(.secondary)
            }
            if showsGlosses, settings.showWordTranslation, let translation = word.translation?.text {
                Text(translation)
                    .font(.system(size: glossFontSize))
                    .foregroundStyle(phase == .current ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .opacity(phase == .upcoming ? 0.55 : 1)
        .blur(radius: isHidden ? 7 : 0)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(phase == .current ? Color.accentColor.opacity(0.16) : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isPronouncing ? 0.8 : 0), lineWidth: 1.5)
        }
        .scaleEffect(phase == .current ? 1.04 : 1)
        .animation(.spring(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.2), value: isHidden)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(phase == .current ? .isSelected : [])
    }

    private var arabicText: Text {
        if settings.isTajweedActive, let tajweed = word.tajweedText {
            return Text(tajweed)
        }
        return Text(word.text(in: settings.script))
    }

    private var glossFontSize: Double {
        max(arabicFontSize * 0.4, 11)
    }
}

private struct VerseEndMarker: View {
    let number: String
    let font: QuranFont
    let fontSize: Double

    var body: some View {
        if font.drawsOrnateAyahMarker {
            Text("\u{06DD}" + number)
                .font(font.font(size: fontSize))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        } else {
            circledNumber
        }
    }

    private var circledNumber: some View {
        Text(number)
            .font(.system(size: fontSize * 0.5, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(minWidth: fontSize * 1.05, minHeight: fontSize * 1.05)
            .background {
                Circle().strokeBorder(.tertiary, lineWidth: 1.5)
            }
            .padding(.top, 6)
            .accessibilityHidden(true)
    }
}
