//
//  TafsirText.swift
//  WordsOfGod
//
//  Created by Rifat on 22/10/26.
//

import Foundation

struct TafsirBlock: Identifiable {
    let id: Int
    let text: String
    let isHeading: Bool

    var isRightToLeft: Bool {
        guard let letter = text.unicodeScalars.first(where: \.properties.isAlphabetic) else { return false }
        return (0x0590...0x08FF).contains(letter.value) || (0xFB1D...0xFEFC).contains(letter.value)
    }
}

extension VerseTafsir {
    // Tafsir HTML only uses <h2>, <p> and <div> for structure, so each becomes one block of plain text.
    var blocks: [TafsirBlock] {
        guard let text else { return [] }
        var blocks: [TafsirBlock] = []
        var isInHeading = false
        var cursor = text.startIndex

        func appendBlock(_ html: Substring) {
            let plain = String(html).withoutTags.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { return }
            blocks.append(TafsirBlock(id: blocks.count, text: plain, isHeading: isInHeading))
        }

        for tag in text.matches(of: /<(\/?)(?:p|div|h([1-6]))\b[^>]*>/) {
            appendBlock(text[cursor..<tag.range.lowerBound])
            if tag.output.2 != nil { isInHeading = tag.output.1.isEmpty }
            cursor = tag.range.upperBound
        }
        appendBlock(text[cursor...])
        return blocks
    }
}

private extension String {
    var withoutTags: String {
        replacing(/<br\s*\/?>/, with: "\n")
            .replacing(/<[^>]+>/, with: "")
            .replacing("&nbsp;", with: " ")
            .replacing("&quot;", with: "\"")
            .replacing("&#39;", with: "'")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&amp;", with: "&")
    }
}
