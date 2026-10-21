//
//  PlaybackKeyMonitor.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

#if os(macOS)
import AppKit

@MainActor
enum PlaybackKeyMonitor {
    private static var monitor: Any?

    private enum KeyCode {
        static let space: UInt16 = 49
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
    }

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event) ? nil : event
        }
    }

    private static func handle(_ event: NSEvent) -> Bool {
        let player = RecitationPlayer.shared
        let hasModifiers = !event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
        guard player.isLoaded, !hasModifiers, !isEditingText(in: event.window) else { return false }

        switch event.keyCode {
        case KeyCode.space:
            player.toggle()
        case KeyCode.rightArrow where player.isPresentationVisible:
            player.nextVerse()
        case KeyCode.leftArrow where player.isPresentationVisible:
            player.previousVerse()
        default:
            return false
        }
        return true
    }

    private static func isEditingText(in window: NSWindow?) -> Bool {
        window?.firstResponder is NSText
    }
}
#endif
