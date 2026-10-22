// TEMPORARY repro hook — remove before committing.
import SwiftUI

enum DebugRepro {
    nonisolated(unsafe) static var isOffline = false

    static func run() async {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-repro"), args.count > index + 1, let chapter = Int(args[index + 1]) else { return }
        let offline = args.contains("-offline")
        print("REPRO start chapter \(chapter) offline=\(offline)")
        while Reader.shared.chapters.isEmpty { try? await Task.sleep(for: .milliseconds(200)) }
        AppSettings.shared.wordTranslationLanguageCode = "en"
        Reader.shared.selectedChapterId = chapter
        if let url = try? await APIClient.shared.getChapterAudio(reciterId: AppSettings.shared.selectedReciterId, chapter: chapter).url {
            print("REPRO downloaded \(await OfflineAudio.shared.download(url))")
        }
        try? await Task.sleep(for: .seconds(3))
        isOffline = offline
        print("REPRO switching language to ur")
        AppSettings.shared.wordTranslationLanguageCode = "ur"
        try? await Task.sleep(for: .seconds(5))
        print("REPRO reopening chapter")
        Reader.shared.selectedChapterId = nil
        try? await Task.sleep(for: .seconds(2))
        Reader.shared.selectedChapterId = chapter
    }
}
