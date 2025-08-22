//
//  AppleMusicLookup.swift
//  apple-music-on-spotify
//
//  Created by Amresh Prasad Sinha on 20/08/25.
//

import Foundation
import OSLog

struct ITunesLookupResponse: Decodable {
    struct Item: Decodable {
        let trackViewUrl: String?
        let collectionViewUrl: String?
        let kind: String?
        let trackId: Int?
    }
    let resultCount: Int
    let results: [Item]
}

final class AppleMusicLookup {
    private let logger = Logger(subsystem: "askck.apple-music-on-spotify", category: "AppleMusicLookup")

    private func albumSlug(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let parts = url.pathComponents
        if let idx = parts.firstIndex(of: "album"), parts.count > idx + 1 {
            return parts[idx + 1]
        }
        return nil
    }

    private func buildSongURL(country: String, collectionViewUrl: String?, trackId: Int?) -> String? {
        guard let coll = collectionViewUrl, let tid = trackId, let slug = albumSlug(from: coll) else { return nil }
        let cc = country.lowercased()
        return "https://music.apple.com/\(cc)/song/\(slug)/\(tid)"
    }
    func urlForISRC(_ isrc: String, country: String) async throws -> String? {
        var comps = URLComponents(string: "https://itunes.apple.com/lookup")!
        comps.queryItems = [
            URLQueryItem(name: "isrc", value: isrc),
            URLQueryItem(name: "country", value: country.lowercased()),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "media", value: "music")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let res = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
        guard let item = res.results.first else { return nil }
        let url = item.trackViewUrl ?? item.collectionViewUrl
        logger.debug("Apple Lookup ISRC=\(isrc, privacy: .public) -> url=\(url ?? "nil", privacy: .public)")
        return url
    }

    func urlForQuery(name: String, artist: String, country: String) async throws -> String? {
        let rawTerm = "\(name) \(artist)"
        let term = rawTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawTerm
        let url = URL(string: "https://itunes.apple.com/search?term=\(term)&country=\(country.lowercased())&entity=song&limit=10&media=music")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let res = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
        // Construct canonical song URL: https://music.apple.com/{cc}/song/{album-slug}/{trackId}
        if let item = res.results.first(where: { $0.kind == "song" }) {
            if let constructed = buildSongURL(country: country, collectionViewUrl: item.collectionViewUrl, trackId: item.trackId) {
                logger.debug("Apple Search term=\(term, privacy: .public) -> constructedSongURL=\(constructed, privacy: .public)")
                return constructed
            }
            // Fallbacks: direct song link if available
            if let tvu = item.trackViewUrl { return tvu }
            // Last resort: album deep link with ?i=trackId
            if let coll = item.collectionViewUrl, let tid = item.trackId { return "\(coll)?i=\(tid)" }
        }
        logger.debug("Apple Search term=\(term, privacy: .public) -> url=nil")
        return nil
    }

    func buildSearchURL(name: String, artist: String, country: String) -> String {
        let rawTerm = "\(name) \(artist)"
        let term = rawTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawTerm
        return "https://itunes.apple.com/search?term=\(term)&country=\(country.lowercased())&entity=song&limit=3&media=music"
    }
}


