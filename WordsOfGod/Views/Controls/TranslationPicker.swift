//
//  TranslationPicker.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct TranslationPicker: View {
    @Bindable private var settings = AppSettings.shared
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search translations", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(10)

            List {
                if searchText.isEmpty, !selectedTranslations.isEmpty {
                    Section("Selected · drag to reorder") {
                        ForEach(selectedTranslations) { translation in
                            TranslationRow(translation: translation)
                        }
                        .onMove { settings.selectedTranslationIds.move(fromOffsets: $0, toOffset: $1) }
                    }
                }

                ForEach(groupedTranslations, id: \.language) { group in
                    Section(group.language.capitalized) {
                        ForEach(group.translations) { translation in
                            TranslationRow(translation: translation)
                        }
                    }
                }
            }
            .overlay { statusOverlay }
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if settings.translations.isEmpty {
            if let error = settings.translationsError {
                ContentUnavailableView("Couldn’t Load Translations", systemImage: "wifi.exclamationmark",
                                       description: Text(error))
            } else {
                ProgressView()
            }
        } else if groupedTranslations.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private var selectedTranslations: [Translation] {
        settings.selectedTranslationIds.compactMap { id in settings.translations.first { $0.id == id } }
    }

    private var groupedTranslations: [(language: String, translations: [Translation])] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matches = settings.translations.filter { translation in
            query.isEmpty || [translation.name, translation.author_name, translation.language_name]
                .contains { $0.localizedStandardContains(query) }
        }
        return Dictionary(grouping: matches, by: \.language_name)
            .map { (language: $0.key, translations: $0.value.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                if lhs.language == "english" { return true }
                if rhs.language == "english" { return false }
                return lhs.language < rhs.language
            }
    }
}

private struct TranslationRow: View {
    let translation: Translation
    private let settings = AppSettings.shared

    private var isSelected: Bool { settings.isTranslationSelected(translation.id) }

    var body: some View {
        #if os(macOS)
        Toggle(isOn: Binding(
            get: { isSelected },
            set: { settings.setTranslation(translation.id, selected: $0) }
        )) {
            title
        }
        .toggleStyle(.checkbox)
        #else
        Button {
            settings.setTranslation(translation.id, selected: !isSelected)
        } label: {
            HStack {
                title
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        #endif
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(translation.name)
            if translation.author_name != translation.name {
                Text(translation.author_name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
