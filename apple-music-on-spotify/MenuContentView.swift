//
//  MenuContentView.swift
//  apple-music-on-spotify
//
//  Created by Amresh Prasad Sinha on 21/08/25.
//

import SwiftUI

struct MenuContentView: View {
    @ObservedObject var sync: SyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link.circle.fill").font(.system(size: 22))
                    .foregroundStyle(sync.enabled ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple ↔︎ Spotify")
                        .font(.headline)
                    Text(sync.enabled ? "Mirroring is enabled" : "Mirroring is disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Toggle(isOn: $sync.enabled) {
                Text("Enable mirroring").font(.body)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Now Playing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(sync.status)
                    .font(.callout)
                    .lineLimit(2)
            }
            .padding(10)
            .background(.quaternary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Button("Open Music") {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                    }
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}


