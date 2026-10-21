//
//  RecitationPlayer.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import AVFoundation
import MediaPlayer
import Observation

@MainActor
@Observable
final class RecitationPlayer {
    static let shared = RecitationPlayer()

    struct WordReference: Equatable {
        let verse: Int
        let position: Int
    }

    private(set) var chapter: Chapter?
    private(set) var audio: ChapterAudio?
    private(set) var isPlaying = false
    private(set) var isWaitingToRepeat = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var currentVerse: Int?
    private(set) var currentWord: Int?
    private(set) var pronouncingWord: WordReference?
    private(set) var error: String?

    private(set) var rangeStart: Int?
    private(set) var rangeEnd: Int?
    private(set) var verseRepeatsCompleted = 0
    private(set) var rangeRepeatsCompleted = 0

    var isPresentationVisible = false

    var isLoaded: Bool { chapter != nil }
    var isActivelyPlaying: Bool { isPlaying || isWaitingToRepeat }
    var hasRange: Bool { rangeStart != nil && rangeEnd != nil }
    var verseCount: Int { chapter?.verses_count ?? 0 }

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let pronunciationPlayer = AVPlayer()
    @ObservationIgnored private let settings = AppSettings.shared
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var itemObservations: [NSKeyValueObservation] = []
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var pendingStartTime: Double?
    @ObservationIgnored private var repeatTask: Task<Void, Never>?
    @ObservationIgnored private var activeSeekID = 0
    @ObservationIgnored private var isSeeking = false
    @ObservationIgnored private var lastHandledFinish: Int?

    private init() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        #endif
        player.defaultRate = settings.playbackRate

        observations.append(player.observe(\.timeControlStatus, options: [.initial, .new]) { [unowned self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in self.playbackStateChanged(isPlaying: playing) }
        })

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [unowned self] time in
            MainActor.assumeIsolated { self.tick(time.seconds.isFinite ? time.seconds : 0) }
        }

        notificationTokens.append(NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
        ) { [unowned self] notification in
            let item = notification.object as? AVPlayerItem
            MainActor.assumeIsolated { self.itemDidPlayToEnd(item) }
        })

        configureRemoteCommands()
    }

    // MARK: Loading

    func play(chapter: Chapter, audio: ChapterAudio, fromVerse verse: Int = 1) {
        load(chapter: chapter, audio: audio)
        play(fromVerse: verse)
    }

    func play(chapter: Chapter, audio: ChapterAudio, fromWord position: Int, inVerse verse: Int) {
        load(chapter: chapter, audio: audio)
        let start = audio.timing(forVerse: verse)?.timing(forWord: position)?.start
            ?? audio.timing(forVerse: verse)?.start ?? 0
        startPlayback(at: start)
    }

    private func load(chapter: Chapter, audio: ChapterAudio) {
        let isSameAudio = self.chapter?.id == chapter.id && self.audio?.audio_url == audio.audio_url
        guard !isSameAudio || player.currentItem == nil else { return }
        guard let url = audio.url else {
            error = "Invalid audio URL."
            return
        }

        self.chapter = chapter
        self.audio = audio
        error = nil
        duration = 0
        currentVerse = nil
        currentWord = nil
        clearRange()

        guard OfflineAudio.shared.canPlay(url) else {
            error = "You’re offline and this surah isn’t saved yet. Play or download it once while connected to listen offline."
            player.replaceCurrentItem(with: nil)
            return
        }
        let item = OfflineAudio.shared.playerItem(for: url)
        observe(item)
        player.replaceCurrentItem(with: item)
        OfflineAudio.shared.saveForOfflineInBackground(url)
    }

    private func observe(_ item: AVPlayerItem) {
        itemObservations = [
            item.observe(\.status, options: [.new]) { [unowned self] item, _ in
                let status = item.status
                let message = item.error?.localizedDescription
                Task { @MainActor in self.itemStatusChanged(status, errorMessage: message) }
            },
            item.observe(\.duration, options: [.initial, .new]) { [unowned self] item, _ in
                let seconds = item.duration.seconds
                Task { @MainActor in self.duration = seconds.isFinite ? seconds : 0 }
            }
        ]
    }

    private func itemStatusChanged(_ status: AVPlayerItem.Status, errorMessage: String?) {
        switch status {
        case .readyToPlay:
            if let start = pendingStartTime {
                pendingStartTime = nil
                startPlayback(at: start)
            }
        case .failed:
            error = errorMessage ?? "Audio failed to load."
        default:
            break
        }
    }

    // MARK: Transport

    func play(fromVerse verse: Int) {
        guard let start = audio?.timing(forVerse: verse)?.start else { return }
        startPlayback(at: start)
    }

    func seek(toVerse verse: Int) {
        guard let start = audio?.timing(forVerse: verse)?.start else { return }
        resetRepeatProgress()
        seek(to: start)
    }

    func seek(to seconds: Double) {
        cancelPendingRepeat()
        resetRepeatProgress()
        performSeek(to: seconds)
    }

    func toggle() {
        guard isLoaded else { return }
        if isActivelyPlaying {
            pause()
        } else if player.currentItem == nil, let chapter, let audio {
            play(chapter: chapter, audio: audio, fromVerse: currentVerse ?? 1)
        } else {
            pronunciationPlayer.pause()
            player.play()
        }
    }

    func pause() {
        cancelPendingRepeat()
        player.pause()
    }

    func nextVerse() {
        let next = (currentVerse ?? 0) + 1
        guard next <= verseCount else { return }
        goToVerse(next)
    }

    func previousVerse() {
        guard let current = currentVerse, let timing = audio?.timing(forVerse: current) else {
            goToVerse(1)
            return
        }
        let isNearVerseStart = currentTime - timing.start < 1.5
        goToVerse(isNearVerseStart ? max(current - 1, 1) : current)
    }

    var canGoToNextVerse: Bool { (currentVerse ?? 0) < verseCount }

    func setRate(_ rate: Float) {
        settings.playbackRate = rate
        player.defaultRate = rate
        if player.timeControlStatus != .paused { player.rate = rate }
        updateNowPlaying()
    }

    func stop() {
        cancelPendingRepeat()
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObservations = []
        pendingStartTime = nil
        chapter = nil
        audio = nil
        currentVerse = nil
        currentWord = nil
        currentTime = 0
        duration = 0
        error = nil
        isPresentationVisible = false
        clearRange()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        #endif
    }

    func pronounce(_ word: Word, inVerse verse: Int) {
        guard let path = word.audio_url, let url = APIClient.shared.wordAudioURL(for: path) else { return }
        pause()
        pronouncingWord = WordReference(verse: verse, position: word.position)
        pronunciationPlayer.replaceCurrentItem(with: OfflineAudio.shared.playerItem(for: url))
        pronunciationPlayer.play()
    }

    func goToVerse(_ verse: Int) {
        isActivelyPlaying ? play(fromVerse: verse) : seek(toVerse: verse)
    }

    private func startPlayback(at seconds: Double) {
        cancelPendingRepeat()
        resetRepeatProgress()
        pronunciationPlayer.pause()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        guard player.currentItem?.status == .readyToPlay else {
            pendingStartTime = seconds
            syncPosition(to: seconds)
            return
        }
        performSeek(to: seconds)
        player.play()
    }

    private func performSeek(to seconds: Double) {
        activeSeekID += 1
        let seekID = activeSeekID
        isSeeking = true
        lastHandledFinish = nil
        syncPosition(to: seconds)
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { [unowned self] _ in
            Task { @MainActor in
                guard seekID == self.activeSeekID else { return }
                self.isSeeking = false
            }
        }
    }

    // MARK: Position tracking

    private func tick(_ time: Double) {
        guard player.currentItem != nil, !isWaitingToRepeat, !isSeeking else { return }
        if let finishedVerse = verseJustFinished(at: time), lastHandledFinish != finishedVerse {
            lastHandledFinish = finishedVerse
            if handleVerseFinished(finishedVerse) { return }
        }
        syncPosition(to: time)
    }

    private func syncPosition(to time: Double) {
        currentTime = time
        let timing = audio?.verseTiming(at: time)
        let isBeforeFirstVerse = time < (audio?.timestamps.first?.start ?? 0)
        let verse = timing?.verseNumber ?? (isBeforeFirstVerse ? nil : currentVerse)
        let word = timing?.wordPosition(at: time)
        if currentVerse != verse {
            currentVerse = verse
            updateNowPlaying()
        }
        if currentWord != word { currentWord = word }
    }

    private func verseJustFinished(at time: Double) -> Int? {
        guard let verse = currentVerse, let end = audio?.timing(forVerse: verse)?.end else { return nil }
        return (end...end + 1).contains(time) ? verse : nil
    }

    private func itemDidPlayToEnd(_ item: AVPlayerItem?) {
        if item === pronunciationPlayer.currentItem {
            pronouncingWord = nil
            return
        }
        guard item === player.currentItem, !isSeeking, !isWaitingToRepeat else { return }
        OfflineAudio.shared.storageChanged()
        let lastVerse = currentVerse ?? verseCount
        if lastHandledFinish != lastVerse, handleVerseFinished(lastVerse) { return }
        player.pause()
        seek(toVerse: rangeStart ?? 1)
    }

    // MARK: Repeat

    func setRange(from start: Int, to end: Int) {
        rangeStart = min(start, end)
        rangeEnd = max(start, end)
        resetRepeatProgress()
    }

    func clearRange() {
        rangeStart = nil
        rangeEnd = nil
        resetRepeatProgress()
    }

    var repeatProgress: String? {
        var parts: [String] = []
        if settings.verseRepeatCount > 1 {
            parts.append(progressText("Verse", completed: verseRepeatsCompleted, total: settings.verseRepeatCount))
        }
        if let rangeStart, let rangeEnd {
            let range = rangeStart == rangeEnd ? "\(rangeStart)" : "\(rangeStart)–\(rangeEnd)"
            parts.append(progressText("Verses \(range)", completed: rangeRepeatsCompleted, total: settings.rangeRepeatCount))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func progressText(_ label: String, completed: Int, total: Int) -> String {
        total == RepeatCount.infinite
            ? "\(label) · pass \(completed + 1)"
            : "\(label) · \(completed + 1) of \(total)"
    }

    private func handleVerseFinished(_ verse: Int) -> Bool {
        if verseRepeatsCompleted + 1 < settings.verseRepeatCount {
            verseRepeatsCompleted += 1
            restart(atVerse: verse)
            return true
        }
        verseRepeatsCompleted = 0

        guard let rangeStart, verse == rangeEnd else { return false }
        if rangeRepeatsCompleted + 1 < settings.rangeRepeatCount {
            rangeRepeatsCompleted += 1
            restart(atVerse: rangeStart)
        } else {
            player.pause()
            seek(toVerse: rangeStart)
        }
        return true
    }

    private func restart(atVerse verse: Int) {
        guard let start = audio?.timing(forVerse: verse)?.start else { return }
        let pause = settings.pauseBetweenRepeats
        guard pause > 0 else {
            performSeek(to: start)
            return
        }

        player.pause()
        isWaitingToRepeat = true
        repeatTask = Task {
            try? await Task.sleep(for: .seconds(pause))
            guard !Task.isCancelled else { return }
            isWaitingToRepeat = false
            performSeek(to: start)
            player.play()
        }
    }

    private func cancelPendingRepeat() {
        repeatTask?.cancel()
        repeatTask = nil
        isWaitingToRepeat = false
    }

    private func resetRepeatProgress() {
        verseRepeatsCompleted = 0
        rangeRepeatsCompleted = 0
    }

    // MARK: Now Playing

    private func playbackStateChanged(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateNowPlaying()
    }

    private func updateNowPlaying() {
        guard let chapter else { return }
        let verseSuffix = currentVerse.map { " · \(chapter.id):\($0)" } ?? ""
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: chapter.name_simple + verseSuffix,
            MPMediaItemPropertyArtist: settings.selectedReciter?.name ?? "",
            MPMediaItemPropertyAlbumTitle: chapter.name_arabic,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(settings.playbackRate) : 0
        ]
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = isActivelyPlaying ? .playing : .paused
        #endif
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        func handle(_ command: MPRemoteCommand, _ action: @escaping @MainActor (RecitationPlayer) -> Void) {
            command.addTarget { [unowned self] _ in
                Task { @MainActor in
                    guard self.isLoaded else { return }
                    action(self)
                }
                return .success
            }
        }
        handle(center.togglePlayPauseCommand) { $0.toggle() }
        handle(center.playCommand) { if !$0.isActivelyPlaying { $0.toggle() } }
        handle(center.pauseCommand) { $0.pause() }
        handle(center.nextTrackCommand) { $0.nextVerse() }
        handle(center.previousTrackCommand) { $0.previousVerse() }
    }
}
