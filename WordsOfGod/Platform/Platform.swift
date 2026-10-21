//
//  Platform.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum Spacing {
    #if os(macOS)
    static let readerMargin: CGFloat = 24
    static let verseInset: CGFloat = 20
    #else
    static let readerMargin: CGFloat = 12
    static let verseInset: CGFloat = 12
    #endif
}

enum Clipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

extension Color {
    nonisolated init(lightHex: UInt32, darkHex: UInt32) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkHex : lightHex)
        })
        #else
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
        })
        #endif
    }
}

#if os(macOS)
private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: hex.red, green: hex.green, blue: hex.blue, alpha: 1)
    }
}
#else
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: hex.red, green: hex.green, blue: hex.blue, alpha: 1)
    }
}
#endif

private extension UInt32 {
    var red: CGFloat { CGFloat((self >> 16) & 0xFF) / 255 }
    var green: CGFloat { CGFloat((self >> 8) & 0xFF) / 255 }
    var blue: CGFloat { CGFloat(self & 0xFF) / 255 }
}
