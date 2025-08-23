# Apple Music on Spotify

Mirror what you’re playing in Spotify to Apple Music on macOS. Lightweight menu bar app that reads Spotify’s now playing, finds the matching Apple Music song, and opens it in Music.

- macOS: 15 Sequoia or later (my system)
- Architecture: Universal (Apple Silicon + Intel) if you build as such in Xcode
- No Spotify account keys: Uses AppleScript to read Spotify’s current track. No Spotify Web API, no client secrets.

## Features
- Menu bar toggle to enable/disable mirroring
- Now playing status in the menu
- Opens the matching Apple Music song using Apple’s Search API
- Automation-friendly: requests permission to control Music and optionally Shortcuts

How matching works:
- Reads track name/artist from Spotify via AppleScript
- Queries Apple’s iTunes Search API (see: https://performance-partners.apple.com/search-api)
- Prefers a canonical song URL like `https://music.apple.com/<cc>/song/<album-slug>/<trackId>`
- Falls back to trackViewUrl or an album link with `?i=<trackId>` if needed

## Download
Prebuilt releases are published on the GitHub Releases page of this repository.

Because this app is not notarized (no paid Developer ID), macOS Gatekeeper will block it on first launch. See First Run below for how to open it.

## First Run (Permissions and Gatekeeper)
1. Move the app to `/Applications`.
2. Right‑click the app → Open → Open. Alternatively remove quarantine:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/apple-music-on-spotify.app"
   ```
3. On first use, macOS will ask you to allow the app to control other apps via Automation. Allow control for:
   - Music
   - Shortcuts (if you use the optional helper shortcut)
   - Spotify (to read now playing via AppleScript)
4. If you accidentally denied prompts, reset Automation permissions and try again:
   ```bash
   tccutil reset AppleEvents $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "apple-music-on-spotify/apple-music-on-spotify/Info.plist")
   ```

Shortcuts helper:
- Install the Shortcut “Play Music From URL (new)”: https://www.icloud.com/shortcuts/f96a19938bf9467f9ed9403547242852
- The app will prompt you to install it if not found. Without this shortcut, this app will not be aple to open Apple Music URLs.

## Usage
- Launch the app: a link icon appears in the menu bar.
- Use the menu to toggle Enable mirroring.
- Start music in Spotify; the app mutes Spotify and opens the same song in Music.

## Build from Source
Prerequisites: Xcode 15+, macOS 15+

1. Open the project in Xcode.
2. Select the `apple-music-on-spotify` scheme.
3. Build and run.

Release build:
- Product → Scheme → Edit Scheme → set Build Configuration to `Release`.
- Product → Clean Build Folder, then Build.

Optional ad‑hoc signing (no certificate):
```bash
codesign --force --deep --timestamp=none -s - \
  --entitlements "apple-music-on-spotify/apple-music-on-spotify/apple_music_on_spotify.entitlements" \
  "/path/to/apple-music-on-spotify.app"
codesign --verify --deep --strict "/path/to/apple-music-on-spotify.app"
```

## FAQ / Troubleshooting
- Nothing happens when mirroring is enabled
  - Ensure Spotify is running and playing a track (not a podcast episode).
  - Check System Settings → Privacy & Security → Automation:
    - Allow this app to control Music, Shortcuts, and Spotify.
  - Reset Automation prompts:
    ```bash
    tccutil reset AppleEvents $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "apple-music-on-spotify/apple-music-on-spotify/Info.plist")
    ```
- Sandbox/Automation denial in Console
  - Ensure entitlements are present (they are in the app). If building locally, prefer running from `/Applications` and use the ad‑hoc signing step above.
- It opens an album URL instead of the exact song
  - The app constructs canonical song URLs using the album slug and `trackId`. Some rare tracks may still resolve to album pages; please open an issue with the track details.
- Right‑click on the status bar icon doesn’t open the menu
  - The menu opens on left‑click. If you need a context menu, please file an issue; we can add a right‑click handler if needed.

## Project Structure
- `AppleScriptBridge.swift`: AppleScript helpers to read Spotify state and control Music
- `AppleMusicLookup.swift`: iTunes Search API client and canonical song URL builder
- `SyncManager.swift`: polling loop, resolution, menu status updates
- `MenuContentView.swift`: the menu bar UI
- `apple_music_on_spotify.entitlements`: sandbox entitlements for Automation and networking

Note: The app does not use Spotify Web API or OAuth.

## Privacy
- No analytics, no telemetry, no servers. All lookups are sent directly to Apple’s iTunes Search API over HTTPS.
- The app requests macOS Automation permission to control Music/Shortcuts locally.

## Contributing
Issues and PRs are welcome!
- Keep code clear and idiomatic Swift.
- Prefer small, focused PRs with screenshots for UI changes.
- For new features, open an issue to discuss the approach first.

Local development tips:
- Use `Console.app` to watch for messages from subsystem `askck.apple-music-on-spotify`.
- If Automation prompts don’t show, try resetting AppleEvents (see above).

## License
GNU GPL. See `LICENSE`.

## Disclaimer
This project is not affiliated with, endorsed by, or sponsored by Apple Inc. or Spotify AB. All product names, logos, and brands are property of their respective owners.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=askck/amos&type=Date)](https://www.star-history.com/#askck/amos&Date)