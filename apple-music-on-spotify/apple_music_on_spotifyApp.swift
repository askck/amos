//
//  apple_music_on_spotifyApp.swift
//  apple-music-on-spotify
//
//  Created by Amresh Prasad Sinha on 20/08/25.
//

import SwiftUI
import AppKit

@main
struct apple_music_on_spotifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sync = SyncManager()
    var body: some Scene {
        MenuBarExtra("AM↔︎SP", systemImage: "link") {
            MenuContentView(sync: sync)
        }
        .menuBarExtraStyle(.window)
    }
}
