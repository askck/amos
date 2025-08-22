//
//  AppleScriptBridge.swift
//  apple-music-on-spotify
//
//  Created by Amresh Prasad Sinha on 20/08/25.
//

import Foundation
import AppKit
import OSLog

struct SpotifyNowPlaying {
    let rawId: String
    let name: String
    let artist: String
    let album: String
    let durationMs: Int
    let positionSec: Double
}

enum AppleScriptBridge {
    private static let logger = Logger(subsystem: "askck.apple-music-on-spotify", category: "AppleScript")
    private static let worker = DispatchQueue(label: "amsp.applescript.worker", qos: .userInitiated)
    static func run(_ source: String) -> String? {
        let script = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let result = script?.executeAndReturnError(&errorInfo)
        if let errorInfo { logger.error("AppleScript error: \(String(describing: errorInfo), privacy: .public) | src=\(source, privacy: .public)") }
        return result?.stringValue
    }

    static func getSpotifyNowPlaying() -> SpotifyNowPlaying? {
        let script = """
        tell application "Spotify"
            if it is running then
                set s to player state as text
                if s is "playing" then
                    set t to current track
                    return (spotify url of t) & "|" & (name of t) & "|" & (artist of t) & "|" & (album of t) & "|" & (duration of t as text) & "|" & (player position as text)
                else
                    return "STATE|" & s
                end if
            else
                display dialog "Spotify is not running." buttons {"OK"} default button "OK"
                return "STATE|not running"
            end if
        end tell
        """
        guard let out = run(script) else {
            logger.debug("getSpotifyNowPlaying: no output")
            return nil
        }
        if out.hasPrefix("STATE|") { return nil }
        let parts = out.components(separatedBy: "|")
        guard parts.count == 6,
              let dur = Int(parts[4]),
              let pos = Double(parts[5]) else {
            logger.debug("getSpotifyNowPlaying: failed to parse output: \(out, privacy: .public)")
            return nil
        }
        let np = SpotifyNowPlaying(rawId: parts[0], name: parts[1], artist: parts[2], album: parts[3], durationMs: dur, positionSec: pos)
        logger.debug("NowPlaying: id=\(np.rawId, privacy: .public) name=\(np.name, privacy: .public) artist=\(np.artist, privacy: .public) pos=\(np.positionSec, format: .fixed(precision: 2))")
        return np
    }

    static func getSpotifyNowPlayingAsync() async -> SpotifyNowPlaying? {
        await withCheckedContinuation { continuation in
            worker.async {
                let value = getSpotifyNowPlaying()
                continuation.resume(returning: value)
            }
        }
    }

    static func isSpotifyRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    }

    static func launchSpotifyIfNeeded() {
        guard !isSpotifyRunning() else { return }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            logger.info("Requested launch of Spotify for automation consent")
        }
    }

    static func requestAutomationConsentIfPossible() {
        // Send harmless events to trigger the Automation prompt
        _ = run("tell application \"Music\" to get name")
        if isSpotifyRunning() { _ = run("tell application \"Spotify\" to get name") }
    }

    static func setSpotifyVolume(_ vol: Int) {
        let v = max(0, min(100, vol))
        logger.debug("setSpotifyVolume -> \(v)")
        _ = run(#"tell application "Spotify" to set sound volume to \#(v)"#)
    }

    static func setMusicVolume(_ vol: Int) {
        let v = max(0, min(100, vol))
        logger.debug("setMusicVolume -> \(v)")
        // _ = run(#"tell application "Music" to set sound volume to \#(v)"#)
    }

    static func openMusic(url: String) {
        logger.debug("openMusic url=\(url, privacy: .public)")
        let script = """
        set u to "\(url)"
        tell application "Music"
            open location u
            delay 0.8
            play
        end tell
        """
        // _ = run(script)
    }

    static func runShortcut(name: String, input: String) {
        logger.debug("runShortcut name=\(name, privacy: .public) input=\(input, privacy: .public)")
        let script = """
        tell application "Shortcuts Events"
            run shortcut named "\(name)" with input "\(input)"
        end tell
        """
        _ = run(script)
    }

    static func seekMusic(to seconds: Double) {
        let s = max(0.0, seconds)
        logger.debug("seekMusic -> \(s, format: .fixed(precision: 2))s")
        // _ = run(#"tell application "Music" to set player position to \#(s)"#)
    }

    static func playMusic() {
        logger.debug("playMusic")
        // _ = run(#"tell application "Music" to play"#)
    }

    static func pauseMusic() {
        logger.debug("pauseMusic")
        // _ = run(#"tell application "Music" to pause"#)
    }
}


