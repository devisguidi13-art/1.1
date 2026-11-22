import Foundation

/// Lightweight, on-device taste model. It learns from existing listening data
/// and never uploads a profile or claims to analyse the actual audio signal.
struct IntelligenceSkipEvent: Codable {
    let track: MusicTrack
    let date: Date
    let listenedSeconds: Double
    let durationSeconds: Double

    var skipWeight: Double {
        guard durationSeconds > 0 else { return 1.0 }
        let fraction = max(0, min(1, listenedSeconds / durationSeconds))
        if fraction < 0.12 { return 2.0 }
        if fraction < 0.30 { return 1.45 }
        if fraction < 0.60 { return 0.75 }
        return 0.25
    }
}

struct DVSIntelligence {
    private static let profileWindow: TimeInterval = 120 * 24 * 60 * 60
    private static let sessionWindow: TimeInterval = 3 * 60 * 60

    /// A bounded profile score for a candidate. Positive history builds taste;
    /// recent session signals temporarily steer the radio without rewriting it.
    func score(for candidate: MusicTrack, favorites: [MusicTrack],
               history: [String: ListeningRecord], skips: [IntelligenceSkipEvent] = [],
               session: [PlayedTrackEntry] = [], now: Date = Date()) -> Double {
        let artist = MusicMetadata.identity(for: candidate).artist
        let style = MusicDiscoveryService.style(for: artist)
        guard !style.isEmpty else { return artistScore(artist, favorites: favorites, history: history) * 0.45 }

        let targetArtist = MusicMetadata.normalized(artist)
        var positive: Double = 0
        var negative: Double = 0
        for record in history.values {
            let heardArtist = MusicMetadata.identity(for: record.track).artist
            guard MusicDiscoveryService.style(for: heardArtist) == style else { continue }
            let age = max(0, now.timeIntervalSince(record.lastPlayed))
            let recency = age > Self.profileWindow ? 0.25 : (1.0 - 0.55 * age / Self.profileWindow)
            positive += (min(5, record.seconds / 480) + min(3, Double(record.plays) * 0.45)) * recency
            negative += Double(record.skips) * 1.25 * recency
        }
        for event in skips where now.timeIntervalSince(event.date) >= 0 && now.timeIntervalSince(event.date) <= Self.profileWindow {
            guard MusicDiscoveryService.style(for: MusicMetadata.identity(for: event.track).artist) == style else { continue }
            let age = max(0, now.timeIntervalSince(event.date))
            let recency = 1.0 - 0.5 * age / Self.profileWindow
            negative += event.skipWeight * 2.2 * recency
            if MusicMetadata.normalized(MusicMetadata.identity(for: event.track).artist) == targetArtist {
                negative += event.skipWeight * 1.25 * recency
            }
        }
        let favoriteStyle = favorites.contains { MusicDiscoveryService.style(for: MusicMetadata.identity(for: $0).artist) == style }
        let favoriteBoost = favoriteStyle ? 4.0 : 0
        let learned = max(-18, min(22, positive * 0.42 - negative * 0.55 + favoriteBoost))

        // Session context is a short-lived nudge: styles heard recently are
        // amplified only when they were actually played in the current session.
        let recent = session.filter { now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) <= Self.sessionWindow }
        var sessionCounts: [String: Double] = [:]
        for entry in recent {
            let heardStyle = MusicDiscoveryService.style(for: MusicMetadata.identity(for: entry.track).artist)
            if !heardStyle.isEmpty { sessionCounts[heardStyle, default: 0] += 1 }
        }
        let sessionBoost = min(12, sessionCounts[style, default: 0] * 2.5)
        return learned + sessionBoost + artistScore(artist, favorites: favorites, history: history) * 0.5
    }

    private func artistScore(_ artist: String, favorites: [MusicTrack], history: [String: ListeningRecord]) -> Double {
        let target = MusicMetadata.normalized(artist)
        guard !target.isEmpty else { return 0 }
        let isFavorite = favorites.contains { MusicMetadata.normalized(MusicMetadata.identity(for: $0).artist) == target }
        var seconds: Double = 0
        var plays = 0
        var skips = 0
        for record in history.values where MusicMetadata.normalized(MusicMetadata.identity(for: record.track).artist) == target {
            seconds += record.seconds; plays += record.plays; skips += record.skips
        }
        return max(-16, min(20, (isFavorite ? 8 : 0) + min(8, seconds / 900) + min(5, Double(plays)) - min(18, Double(skips) * 3)))
    }
}
