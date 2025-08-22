//
//  SyncManager.swift
//  apple-music-on-spotify
//
//  Created by Amresh Prasad Sinha on 20/08/25.
//

import Foundation
import OSLog

@MainActor
final class SyncManager: ObservableObject {
    @Published var enabled = false {
        didSet { enabled ? start() : stop() }
    }
    @Published var status: String = "Idle"

    private var timer: DispatchSourceTimer?
    private func extractSpotifyTrackID(from raw: String) -> String? {
        if raw.contains("spotify:track:") { return raw.components(separatedBy: ":").last }
        if raw.contains("/track/") {
            if let comp = raw.components(separatedBy: "/track/").last?.components(separatedBy: "?").first { return comp }
        }
        if raw.contains("spotify:episode:") || raw.contains("spotify:local:") { return nil }
        return raw
    }
    private let am = AppleMusicLookup()
    private var lastTrackId: String?
    private var isResolving = false
    private var cache: [String: String] = [:] // spotifyTrackId -> Apple Music URL
    private let logger = Logger(subsystem: "askck.apple-music-on-spotify", category: "Sync")

    private var country: String {
        Locale.current.region?.identifier ?? "US"
    }

    func start() {
        if timer != nil { return }
        status = "Running"
        logger.info("Sync started")
        // Nudge apps to launch and show Automation consent
        AppleScriptBridge.launchSpotifyIfNeeded()
        AppleScriptBridge.requestAutomationConsentIfPossible()
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        t.schedule(deadline: .now(), repeating: .milliseconds(800))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task.detached { await self.tick() }
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
        status = "Stopped"
        logger.info("Sync stopped")
    }

    private func tick() async {
        if !AppleScriptBridge.isSpotifyRunning() {
            await MainActor.run { self.status = "Spotify not running" }
            logger.debug("Spotify process not running")
            return
        }

        guard let np = await AppleScriptBridge.getSpotifyNowPlayingAsync() else {
            await MainActor.run { self.status = "Waiting for playback" }
            logger.debug("No playback detected")
            return
        }

        await MainActor.run { self.status = "Playing: \(np.name) — \(np.artist)" }
        AppleScriptBridge.setSpotifyVolume(0)

        // Ignore non-track content such as episodes
        if np.rawId.contains("spotify:episode:") { return }

        let spId = extractSpotifyTrackID(from: np.rawId) ?? np.rawId
        if lastTrackId != spId && !isResolving {
            logger.debug("Track change detected: \(self.lastTrackId ?? "nil", privacy: .public) -> \(spId, privacy: .public)")
            isResolving = true
            lastTrackId = spId
            Task.detached { [weak self] in
                guard let self = self else { return }
                let url = await self.resolveURL(for: spId, fallbackName: np.name, artist: np.artist)
                if let url {
                    self.logger.debug("Resolved Apple Music URL: \(url, privacy: .public)")
                    // Use Shortcuts path if the user installed the helper shortcut
                    self.logger.debug("Sending URL to Shortcuts: \(url, privacy: .public)")
                    AppleScriptBridge.runShortcut(name: "Play Music From URL (new)", input: url)
                    // Fallback direct control as backup
                    AppleScriptBridge.setMusicVolume(80)
                    AppleScriptBridge.openMusic(url: url)
                    // Temporarily disabled player position sync
                    // AppleScriptBridge.seekMusic(to: np.positionSec + 0.4)
                } else {
                    self.logger.warning("Failed to resolve Apple Music URL for trackId=\(spId, privacy: .public) name=\(np.name, privacy: .public)")
                }
                await MainActor.run { self.isResolving = false }
            }
        }
    }

    private func resolveURL(for spId: String, fallbackName: String, artist: String) async -> String? {
        if let cached = cache[spId] {
            logger.debug("Cache hit for \(spId, privacy: .public)")
            return cached
        }
        do {
            // Dropped ISRC usage: The iTunes/Apple Search API does not officially
            // support lookup by ISRC. We now resolve strictly via name + artist.
            //
            // if let isrc = try await sp.isrc(for: spId),
            //    let url = try await am.urlForISRC(isrc, country: country) {
            //    cache[spId] = url
            //    return url
            // }
            if let url = try await am.urlForQuery(name: fallbackName, artist: artist, country: country) {
                cache[spId] = url
                return url
            }
        } catch {
            logger.error("resolveURL error: \(String(describing: error), privacy: .public)")
        }
        return nil
    }
}


