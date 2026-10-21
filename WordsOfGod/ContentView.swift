//
//  ContentView.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct ContentView: View {
    @Bindable private var reader = Reader.shared
    private let player = RecitationPlayer.shared

    var body: some View {
        NavigationSplitView {
            ChaptersView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
                #if !os(macOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") { reader.isShowingSettings = true }
                    }
                }
                #endif
        } detail: {
            Group {
                if let chapter = reader.selectedChapter {
                    ChapterDetailView(chapter: chapter)
                        .id(chapter.id)
                } else if reader.isLoadingChapters {
                    ProgressView()
                } else {
                    ContentUnavailableView("Select a Surah",
                                           systemImage: "book.closed",
                                           description: Text("Choose a surah from the sidebar to start reading."))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if player.isLoaded {
                    AudioPlayerBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: player.isLoaded)
        }
        .task { await reader.loadChapters() }
        #if !os(macOS)
        .sheet(isPresented: $reader.isShowingSettings) { SettingsView() }
        #endif
    }
}

#Preview {
    ContentView()
}
