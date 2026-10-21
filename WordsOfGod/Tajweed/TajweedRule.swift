//
//  TajweedRule.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

nonisolated enum TajweedRule: String, CaseIterable, Identifiable {
    case hamzatWasl = "ham_wasl"
    case lamShamsiyyah = "laam_shamsiyah"
    case silent = "slnt"
    case naturalMadd = "madda_normal"
    case permissibleMadd = "madda_permissible"
    case connectedObligatoryMadd = "madda_obligatory_mottasel"
    case separatedObligatoryMadd = "madda_obligatory_monfasel"
    case necessaryMadd = "madda_necessary"
    case ghunnah = "ghunnah"
    case ikhfa = "ikhafa"
    case ikhfaShafawi = "ikhafa_shafawi"
    case idghamWithGhunnah = "idgham_ghunnah"
    case idghamWithoutGhunnah = "idgham_wo_ghunnah"
    case idghamShafawi = "idgham_shafawi"
    case idghamMutajanisayn = "idgham_mutajanisayn"
    case idghamMutaqaribayn = "idgham_mutaqaribayn"
    case iqlab = "iqlab"
    case qalqalah = "qalaqah"

    var id: String { rawValue }

    init?(className: String) {
        if className == "madda_obligatory" {
            self = .connectedObligatoryMadd
        } else {
            self.init(rawValue: className)
        }
    }

    var name: String {
        switch self {
        case .hamzatWasl: "Hamzat al-Waṣl"
        case .lamShamsiyyah: "Lām Shamsiyyah"
        case .silent: "Silent Letter"
        case .naturalMadd: "Natural Madd"
        case .permissibleMadd: "Permissible Madd"
        case .connectedObligatoryMadd: "Obligatory Madd (Muttaṣil)"
        case .separatedObligatoryMadd: "Obligatory Madd (Munfaṣil)"
        case .necessaryMadd: "Necessary Madd"
        case .ghunnah: "Ghunnah"
        case .ikhfa: "Ikhfāʾ"
        case .ikhfaShafawi: "Ikhfāʾ Shafawī"
        case .idghamWithGhunnah: "Idghām with Ghunnah"
        case .idghamWithoutGhunnah: "Idghām without Ghunnah"
        case .idghamShafawi: "Idghām Shafawī"
        case .idghamMutajanisayn: "Idghām Mutajānisayn"
        case .idghamMutaqaribayn: "Idghām Mutaqāribayn"
        case .iqlab: "Iqlāb"
        case .qalqalah: "Qalqalah"
        }
    }

    var explanation: String {
        switch self {
        case .hamzatWasl: "Not pronounced when continuing from the previous word"
        case .lamShamsiyyah: "Lām of “al-” merges into the following sun letter"
        case .silent: "Written but not pronounced"
        case .naturalMadd: "Prolong 2 counts"
        case .permissibleMadd: "Prolong 2, 4 or 6 counts"
        case .connectedObligatoryMadd: "Prolong 4–5 counts; hamzah in the same word"
        case .separatedObligatoryMadd: "Prolong 4–5 counts; hamzah in the next word"
        case .necessaryMadd: "Prolong 6 counts"
        case .ghunnah: "Nasalize for 2 counts (nūn or mīm with shaddah)"
        case .ikhfa: "Hide the nūn sound with nasalization"
        case .ikhfaShafawi: "Hide the mīm before bāʾ with nasalization"
        case .idghamWithGhunnah: "Merge the nūn into the next letter with nasalization"
        case .idghamWithoutGhunnah: "Merge the nūn into lām or rāʾ without nasalization"
        case .idghamShafawi: "Merge mīm into mīm with nasalization"
        case .idghamMutajanisayn: "Merge letters sharing the same articulation point"
        case .idghamMutaqaribayn: "Merge letters with close articulation points"
        case .iqlab: "Change the nūn sound to mīm before bāʾ"
        case .qalqalah: "Echo / bounce the letter when it has sukūn"
        }
    }

    var color: Color {
        let (light, dark) = hexColors
        return Color(lightHex: light, darkHex: dark)
    }

    private var hexColors: (light: UInt32, dark: UInt32) {
        switch self {
        case .hamzatWasl, .lamShamsiyyah, .silent: (0xAAAAAA, 0x8A8A8A)
        case .naturalMadd: (0x537FFF, 0x7C9CFF)
        case .permissibleMadd: (0x4050FF, 0x7B86FF)
        case .connectedObligatoryMadd, .separatedObligatoryMadd: (0x2144C1, 0x6B8BFF)
        case .necessaryMadd: (0x000EBC, 0x5F6BFF)
        case .ghunnah: (0xFF7E1E, 0xFF9D52)
        case .ikhfa: (0x9400A8, 0xD76BE6)
        case .ikhfaShafawi: (0xD500B7, 0xFF6BE6)
        case .idghamWithGhunnah: (0x169777, 0x3CC9A4)
        case .idghamWithoutGhunnah: (0x169200, 0x4CC93A)
        case .idghamShafawi: (0x58B800, 0x8BE04A)
        case .idghamMutajanisayn, .idghamMutaqaribayn: (0xA1A1A1, 0x9A9A9A)
        case .iqlab: (0x26BFFD, 0x5FD2FF)
        case .qalqalah: (0xDD0008, 0xFF5A5F)
        }
    }
}

nonisolated enum TajweedText {
    // Input looks like `هُ<rule class=idgham_wo_ghunnah>دًى</rule>`; tags may nest, and the innermost known rule wins.
    // Scans Unicode scalars because a tag's ">" followed by a diacritic forms a single Character.
    static func attributed(_ tagged: String) -> AttributedString {
        var result = AttributedString()
        var openRules: [TajweedRule?] = []
        var remaining = tagged.unicodeScalars[...]

        while let first = remaining.first {
            if first == "<" {
                let tagEnd = remaining.firstIndex(of: ">") ?? remaining.endIndex
                let tag = String(Substring(remaining[remaining.index(after: remaining.startIndex)..<tagEnd]))
                if tag.hasPrefix("/") {
                    if !openRules.isEmpty { openRules.removeLast() }
                } else {
                    openRules.append(rule(in: tag))
                }
                remaining = tagEnd < remaining.endIndex ? remaining[remaining.index(after: tagEnd)...] : remaining[remaining.endIndex...]
            } else {
                let textEnd = remaining.firstIndex(of: "<") ?? remaining.endIndex
                var run = AttributedString(String(Substring(remaining[..<textEnd])))
                if let rule = openRules.compactMap({ $0 }).last {
                    run.foregroundColor = rule.color
                }
                result += run
                remaining = remaining[textEnd...]
            }
        }
        return result
    }

    private static func rule(in tag: String) -> TajweedRule? {
        guard let classRange = tag.firstRange(of: "class=") else { return nil }
        let className = tag[classRange.upperBound...]
            .prefix { !$0.isWhitespace }
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return TajweedRule(className: className)
    }
}
