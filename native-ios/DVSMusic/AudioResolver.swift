import AVFoundation
import Foundation
import YouTubeKit

/// Previously resolved stream URLs can be reused for nearby queue items. Signed URLs
/// are temporary: never persist them to disk or assume they remain valid indefinitely.
private actor StreamURLCache {
    static let shared = StreamURLCache()
    private var items: [String: (URL, Date)] = [:]
    func get(_ id: String) -> URL? {
        guard let value = items[id], Date().timeIntervalSince(value.1) < 10 * 60 else { return nil }
        return value.0
    }
    func put(_ id: String, url: URL) {
        items[id] = (url, Date())
        if items.count > 90 { items.removeAll() }
    }
}

/// Retains the existing (unofficial) iPhone audio resolver used by 0.8.
/// A resolved URL does not guarantee that the origin will start buffering instantly.
struct AudioResolver {
    enum ResolveError: LocalizedError {
        case noAudio
        var errorDescription: String? {
            "La sorgente non ha fornito uno stream audio compatibile per questo brano."
        }
    }

    /// Resolve a direct stream URL. Kept separate from AVPlayerItem creation so
    /// upcoming songs can be warmed in the background and reused on transition.
    private func resolvedURL(for track: MusicTrack) async throws -> URL {
        if track.isAudius {
            guard let direct = AudiusSource.streamURL(for: track) else { throw ResolveError.noAudio }
            return direct
        }
        if let cached = await StreamURLCache.shared.get(track.id) { return cached }
        let streams = try await YouTube(videoID: track.id).streams
        guard let stream = streams
            .filterAudioOnly()
            .filter({ $0.isNativelyPlayable })
            .highestAudioBitrateStream() else { throw ResolveError.noAudio }
        await StreamURLCache.shared.put(track.id, url: stream.url)
        return stream.url
    }

    func playerItem(for track: MusicTrack) async throws -> AVPlayerItem {
        let url = try await resolvedURL(for: track)
        let item = AVPlayerItem(url: url)
        // A shorter initial buffer improves perceived start time; AVPlayer can
        // continue buffering while playback is underway.
        item.preferredForwardBufferDuration = 1.0
        return item
    }

    func warm(_ track: MusicTrack) async {
        guard !track.isAudius else { return }
        _ = try? await resolvedURL(for: track)
    }

    /// Warm a small queue window with bounded concurrency to reduce next-track
    /// gaps without flooding YouTube with parallel stream-resolution requests.
    func prefetch(_ tracks: [MusicTrack], concurrency: Int = 2) async {
        guard !tracks.isEmpty else { return }
        var cursor = 0
        while cursor < tracks.count {
            let batch = Array(tracks[cursor..<min(tracks.count, cursor + max(1, concurrency))])
            await withTaskGroup(of: Void.self) { group in
                for track in batch { group.addTask { await self.warm(track) } }
            }
            cursor += batch.count
        }
    }
}
