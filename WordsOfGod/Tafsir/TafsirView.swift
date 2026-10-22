//
//  TafsirView.swift
//  WordsOfGod
//
//  Created by Rifat on 22/10/26.
//

import SwiftUI

struct TafsirView: View {
    let verseKey: String
    @Bindable private var settings = AppSettings.shared
    @State private var tafsir: VerseTafsir?
    @State private var error: String?

    private var requestKey: String { "\(settings.selectedTafsirId):\(verseKey)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                content
            }
            .padding(Spacing.verseInset)
        }
        .task(id: requestKey) { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tafsir · \(coverage)")
                .font(.headline)

            Picker("Source", selection: $settings.selectedTafsirId) {
                ForEach(groupedTafsirs, id: \.language) { group in
                    Section(group.language.capitalized) {
                        ForEach(group.tafsirs) { Text($0.name).tag($0.id) }
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let tafsir, !tafsir.isEmpty {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(tafsir.blocks) { block in
                    Text(block.text)
                        .font(block.isHeading ? .headline : .system(size: settings.translationFontSize))
                        .lineSpacing(block.isHeading ? 0 : settings.translationFontSize * 0.25)
                        .multilineTextAlignment(block.isRightToLeft ? .trailing : .leading)
                        .frame(maxWidth: .infinity, alignment: block.isRightToLeft ? .trailing : .leading)
                        .padding(.top, block.isHeading ? 6 : 0)
                }
            }
            .textSelection(.enabled)
        } else if tafsir != nil {
            ContentUnavailableView("No Commentary",
                                   systemImage: "text.book.closed",
                                   description: Text("\(settings.selectedTafsir?.name ?? "This tafsir") has no commentary for \(verseKey)."))
        } else if let error {
            ContentUnavailableView {
                Label("Couldn’t Load Tafsir", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(40)
        }
    }

    private var coverage: String {
        let keys = tafsir?.coveredVerseKeys ?? []
        guard keys.count > 1, let first = keys.first, let last = keys.last?.split(separator: ":").last else {
            return verseKey
        }
        return "\(first)–\(last)"
    }

    private var groupedTafsirs: [(language: String, tafsirs: [Tafsir])] {
        Dictionary(grouping: settings.tafsirs, by: \.language_name)
            .map { (language: $0.key, tafsirs: $0.value.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                if lhs.language == "english" { return true }
                if rhs.language == "english" { return false }
                return lhs.language < rhs.language
            }
    }

    private func load() async {
        tafsir = nil
        error = nil
        do {
            tafsir = try await APIClient.shared.getTafsir(settings.selectedTafsirId, verseKey: verseKey)
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
