//
//  OfflineViews.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct OfflineDownloadButton: View {
    let audioURL: URL?
    private let offline = OfflineAudio.shared

    var body: some View {
        if let audioURL {
            if let progress = offline.downloadProgress[audioURL] {
                Button {
                    offline.cancelDownload(audioURL)
                } label: {
                    Label("Downloading \(progress.formatted(.percent.precision(.fractionLength(0)))) — Cancel",
                          systemImage: "stop.circle")
                }
            } else if offline.isDownloaded(audioURL) {
                Button(role: .destructive) {
                    offline.removeDownload(audioURL)
                } label: {
                    Label("Remove Download", systemImage: "trash")
                }
            } else {
                Button {
                    Task { await offline.download(audioURL) }
                } label: {
                    Label("Download for Offline", systemImage: "arrow.down.circle")
                }
            }
        }
    }
}

struct OfflineStatusBadge: View {
    let audioURL: URL?
    private let offline = OfflineAudio.shared

    var body: some View {
        if let audioURL {
            if let progress = offline.downloadProgress[audioURL] {
                ProgressView(value: progress) {
                    Text("Downloading for offline…")
                }
                .frame(maxWidth: 220)
            } else if offline.isAvailableOffline(audioURL) {
                Label("Available offline", systemImage: "checkmark.icloud")
                    .foregroundStyle(.green)
            } else if let error = offline.downloadErrors[audioURL] {
                Label(error, systemImage: "exclamationmark.icloud")
                    .foregroundStyle(.red)
            }
        }
    }
}

struct OfflineSettingsSection: View {
    @Bindable private var settings = AppSettings.shared
    private let offline = OfflineAudio.shared
    private let reader = Reader.shared

    var body: some View {
        Section {
            Toggle("Save surahs I play for offline listening", isOn: $settings.savesPlayedSurahs)
            Toggle("Save over cellular and Low Data Mode", isOn: $settings.savesOverCellular)
                .disabled(!settings.savesPlayedSurahs)

            if let progress = offline.libraryProgress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(progress.completed), total: Double(progress.total))
                    Text("\(progress.completed) of \(progress.total) surahs · \(progress.currentChapter)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Stop Downloading", role: .cancel) { offline.cancelLibraryDownload() }
            } else {
                Button("Download All Surahs", systemImage: "arrow.down.circle") {
                    offline.downloadLibrary(reader.chapters)
                }
                .disabled(reader.chapters.isEmpty)
            }

            storageRow("Downloaded surahs", size: offline.downloadsSize,
                       action: "Remove All", perform: offline.removeAllDownloads)
            storageRow("Streamed audio cache", size: offline.streamingCacheSize,
                       action: "Clear", perform: offline.clearStreamingCache)
            storageRow("Text and timings", size: ResponseCache.shared.size,
                       action: "Clear") {
                ResponseCache.shared.clear()
                offline.storageChanged()
            }
        } header: {
            Text("Offline")
        } footer: {
            Text("Text, translations and timings you open are kept automatically. Surahs you play are saved in full in the background, so they work without a connection. “Download All Surahs” saves every surah with the current reciter and translations.")
                .foregroundStyle(.secondary)
        }
    }

    private func storageRow(_ title: String, size: Int64, action: String, perform: @escaping () -> Void) -> some View {
        LabeledContent(title) {
            HStack {
                Text(size.formatted(.byteCount(style: .file)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button(action, role: .destructive, action: perform)
                    .disabled(size == 0)
            }
        }
    }
}
