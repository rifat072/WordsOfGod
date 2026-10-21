//
//  OfflineAudio.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import AVFoundation
import Network
import Observation
import PersistentAVPlayerItem

@MainActor
@Observable
final class OfflineAudio {
    static let shared = OfflineAudio()

    struct LibraryProgress {
        var completed: Int
        let total: Int
        var currentChapter: String
    }

    private(set) var downloadProgress: [URL: Double] = [:]
    private(set) var downloadErrors: [URL: String] = [:]
    private(set) var libraryProgress: LibraryProgress?
    private(set) var storageRevision = 0
    private(set) var isOnline = true

    @ObservationIgnored let streamingCache = MediaCache(directory: OfflineStorage.directory("StreamingCache"),
                                                        maxDiskSize: 2 * 1024 * 1024 * 1024)
    @ObservationIgnored private let downloadsDirectory = OfflineStorage.directory("Downloads")
    @ObservationIgnored private var downloadTasks: [URL: URLSessionDownloadTask] = [:]
    @ObservationIgnored private var progressObservations: [URL: NSKeyValueObservation] = [:]
    @ObservationIgnored private var downloadWaiters: [URL: [CheckedContinuation<Bool, Never>]] = [:]
    @ObservationIgnored private var libraryTask: Task<Void, Never>?
    @ObservationIgnored private let pathMonitor = NWPathMonitor()
    @ObservationIgnored private let backgroundSaveSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.allowsExpensiveNetworkAccess = false
        configuration.allowsConstrainedNetworkAccess = false
        return URLSession(configuration: configuration)
    }()

    private init() {
        pathMonitor.pathUpdateHandler = { [unowned self] path in
            let online = path.status == .satisfied
            Task { @MainActor in if self.isOnline != online { self.isOnline = online } }
        }
        pathMonitor.start(queue: DispatchQueue(label: "WordsOfGod.network-path"))
    }

    // MARK: Playback

    func playerItem(for url: URL) -> AVPlayerItem {
        if isDownloaded(url) { return AVPlayerItem(url: downloadedFileURL(for: url)) }
        return PersistentAVPlayerItem(url: url, cache: streamingCache)
    }

    func isDownloaded(_ url: URL) -> Bool {
        _ = storageRevision
        return FileManager.default.fileExists(atPath: downloadedFileURL(for: url).path)
    }

    func isAvailableOffline(_ url: URL) -> Bool {
        isDownloaded(url) || streamingCache.isCached(url)
    }

    func isDownloading(_ url: URL) -> Bool { downloadProgress[url] != nil }

    func canPlay(_ url: URL) -> Bool {
        isOnline || isAvailableOffline(url)
    }

    func saveForOfflineInBackground(_ url: URL) {
        guard AppSettings.shared.savesPlayedSurahs, !isAvailableOffline(url) else { return }
        let session = AppSettings.shared.savesOverCellular ? URLSession.shared : backgroundSaveSession
        startDownload(url, using: session)
    }

    // MARK: Single downloads

    @discardableResult
    func download(_ url: URL) async -> Bool {
        if isDownloaded(url) { return true }
        return await withCheckedContinuation { continuation in
            downloadWaiters[url, default: []].append(continuation)
            startDownload(url, using: .shared)
        }
    }

    func cancelDownload(_ url: URL) {
        downloadTasks[url]?.cancel()
    }

    func removeDownload(_ url: URL) {
        try? FileManager.default.removeItem(at: downloadedFileURL(for: url))
        storageRevision += 1
    }

    private func startDownload(_ url: URL, using session: URLSession) {
        guard downloadTasks[url] == nil else { return }
        downloadErrors[url] = nil
        downloadProgress[url] = 0

        let destination = downloadedFileURL(for: url)
        let task = session.downloadTask(with: url) { [unowned self] temporaryURL, response, error in
            // The temporary file is deleted when this handler returns, so it is moved here.
            let failure = Self.moveDownload(temporaryURL, response: response, error: error, to: destination)
            Task { @MainActor in self.downloadFinished(url, failure: failure) }
        }
        progressObservations[url] = task.progress.observe(\.fractionCompleted) { [unowned self] progress, _ in
            let fraction = (progress.fractionCompleted * 100).rounded() / 100
            Task { @MainActor in
                if let current = self.downloadProgress[url], current != fraction { self.downloadProgress[url] = fraction }
            }
        }
        downloadTasks[url] = task
        task.resume()
    }

    nonisolated private static func moveDownload(_ temporaryURL: URL?, response: URLResponse?, error: Error?,
                                                 to destination: URL) -> String? {
        if let error { return (error as? URLError)?.code == .cancelled ? nil : error.localizedDescription }
        guard let temporaryURL, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return "The server didn’t return the audio file."
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func downloadFinished(_ url: URL, failure: String?) {
        downloadTasks[url] = nil
        progressObservations[url] = nil
        downloadProgress[url] = nil
        downloadErrors[url] = failure
        let succeeded = isDownloaded(url)
        if succeeded { streamingCache.remove(url) }
        storageRevision += 1
        downloadWaiters.removeValue(forKey: url)?.forEach { $0.resume(returning: succeeded) }
    }

    // MARK: Whole library

    var isDownloadingLibrary: Bool { libraryTask != nil }

    func downloadLibrary(_ chapters: [Chapter]) {
        guard libraryTask == nil, !chapters.isEmpty else { return }
        let settings = AppSettings.shared
        libraryProgress = LibraryProgress(completed: 0, total: chapters.count, currentChapter: chapters[0].name_simple)

        libraryTask = Task {
            for chapter in chapters {
                guard !Task.isCancelled else { break }
                libraryProgress?.currentChapter = chapter.name_simple
                _ = try? await APIClient.shared.getVerses(chapter: chapter.id,
                                                          translationIds: settings.selectedTranslationIds,
                                                          wordLanguage: settings.wordTranslationLanguageCode)
                if let url = try? await APIClient.shared.getChapterAudio(reciterId: settings.selectedReciterId,
                                                                         chapter: chapter.id).url {
                    await download(url)
                }
                libraryProgress?.completed += 1
            }
            libraryProgress = nil
            libraryTask = nil
        }
    }

    func cancelLibraryDownload() {
        libraryTask?.cancel()
        downloadTasks.values.forEach { $0.cancel() }
    }

    // MARK: Storage

    var downloadsSize: Int64 {
        _ = storageRevision
        return OfflineStorage.size(of: downloadsDirectory)
    }

    var streamingCacheSize: Int64 {
        _ = storageRevision
        return streamingCache.totalSize
    }

    func removeAllDownloads() {
        OfflineStorage.removeContents(of: downloadsDirectory)
        storageRevision += 1
    }

    func clearStreamingCache() {
        streamingCache.clearAll()
        storageRevision += 1
    }

    func storageChanged() { storageRevision += 1 }

    private func downloadedFileURL(for url: URL) -> URL {
        downloadsDirectory.appending(path: OfflineStorage.fileName(for: url.absoluteString,
                                                                   extension: url.pathExtension.isEmpty ? "mp3" : url.pathExtension))
    }
}
