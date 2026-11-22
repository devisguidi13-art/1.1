import Foundation

@main
struct IntelligenceV11Tests {
    static func main() {
        let now = Date()
        let seed = MusicTrack(id: "seed", title: "Seed", artist: "Frank Ocean", duration: 210)
        let preferred = MusicTrack(id: "preferred", title: "Snooze", artist: "SZA", duration: 210)
        let unrelated = MusicTrack(id: "unrelated", title: "Rock song", artist: "Nirvana", duration: 210)
        let record = ListeningRecord(track: seed, seconds: 7_200, plays: 12, skips: 0, lastPlayed: now)
        let model = DVSIntelligence()
        assert(MusicDiscoveryService.style(for: "Yeat") == "rage", "rage artist cluster should resolve")
        assert(MusicDiscoveryService.style(for: "Central Cee") == "drill", "drill artist cluster should resolve")
        assert(MusicDiscoveryService.style(for: "Don Toliver") == "melodic trap", "melodic trap cluster should resolve")
        let base = model.score(for: preferred, favorites: [], history: [:], now: now)
        let learned = model.score(for: preferred, favorites: [seed], history: [seed.id: record], now: now)
        assert(learned > base, "positive listening/favorite profile should boost a related style")
        let earlySkip = IntelligenceSkipEvent(track: preferred, date: now, listenedSeconds: 8, durationSeconds: 210)
        let lateSkip = IntelligenceSkipEvent(track: preferred, date: now, listenedSeconds: 170, durationSeconds: 210)
        let earlyPenalty = model.score(for: preferred, favorites: [], history: [:], skips: [earlySkip], now: now)
        let latePenalty = model.score(for: preferred, favorites: [], history: [:], skips: [lateSkip], now: now)
        assert(earlyPenalty < latePenalty, "early skips should penalize more than late skips")
        let session = [PlayedTrackEntry(id: UUID(), track: preferred, date: now),
                      PlayedTrackEntry(id: UUID(), track: seed, date: now)]
        let sessionScore = model.score(for: preferred, favorites: [], history: [:], session: session, now: now)
        assert(sessionScore > base, "current-session style should temporarily influence recommendations")
        let unrelatedScore = model.score(for: unrelated, favorites: [], history: [:], session: session, now: now)
        assert(sessionScore > unrelatedScore, "session affinity should be specific to its learned style")
        print("OK DVS Intelligence 1.1: profile learning, skip timing, session adaptation")
    }
}
