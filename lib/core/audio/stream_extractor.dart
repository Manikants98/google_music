import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Cache entry holding stream URL candidates and extraction timestamp.
class StreamCacheEntry {
  /// Ordered list of candidate stream URLs (highest quality audio first, muxed fallback last).
  final List<String> candidateUrls;

  /// Timestamp when URLs were extracted.
  final DateTime extractedAt;

  /// Creates cache record.
  const StreamCacheEntry({
    required this.candidateUrls,
    required this.extractedAt,
  });

  /// Primary direct playable audio URL.
  String get url => candidateUrls.isNotEmpty ? candidateUrls.first : '';

  /// Whether the cached stream URL is still valid (under 5 hours old).
  bool get isValid =>
      candidateUrls.isNotEmpty &&
      DateTime.now().difference(extractedAt).inHours < 5;
}

/// Extractor service retrieving direct high-bitrate audio streams.
class AudioStreamExtractor {
  /// YoutubeExplode instance for parsing media manifests.
  final YoutubeExplode _client = YoutubeExplode();

  /// In-memory cache mapping video ID to cached stream entries.
  final Map<String, StreamCacheEntry> _cache = <String, StreamCacheEntry>{};

  /// In-flight de-duplication map for ongoing stream extraction tasks.
  final Map<String, Future<List<String>>> _inFlight =
      <String, Future<List<String>>>{};

  /// Clears in-memory stream URL cache and extracted manifests.
  void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Invalidates cached URL for a video (useful after 403 or network errors).
  void invalidate(String videoId) {
    _cache.remove(videoId);
    _inFlight.remove(videoId);
  }

  /// Returns cached candidate URLs synchronously if available and still valid.
  List<String>? getCachedCandidateUrls(String videoId) {
    final cached = _cache[videoId];
    if (cached != null && cached.isValid) {
      return cached.candidateUrls;
    }
    return null;
  }

  /// Silently pre-fetches and caches direct stream URLs for upcoming tracks in queue.
  Future<void> prefetch(String videoId) async {
    if (videoId.isEmpty) return;
    final cached = _cache[videoId];
    if (cached != null && cached.isValid) return;
    if (_inFlight.containsKey(videoId)) return;
    try {
      await getCandidateStreamUrls(videoId);
    } catch (_) {}
  }

  /// Extracts multiple candidate stream URLs for a video, ordered by playback reliability.
  Future<List<String>> getCandidateStreamUrls(
    String videoId, {
    bool forceRefresh = false,
  }) async {
    if (videoId.isEmpty) return <String>[];

    if (forceRefresh) {
      _cache.remove(videoId);
    }

    final cached = _cache[videoId];
    if (cached != null && cached.isValid) {
      return cached.candidateUrls;
    }

    final inFlight = _inFlight[videoId];
    if (inFlight != null) {
      return inFlight;
    }

    final task = _extractCandidatesInternal(videoId);
    _inFlight[videoId] = task;
    try {
      final result = await task;
      return result;
    } finally {
      _inFlight.remove(videoId);
    }
  }

  /// Internal tiered manifest extraction pipeline.
  Future<List<String>> _extractCandidatesInternal(String videoId) async {
    /// Tier 1: Fast-path web client extraction with watch page bypass.
    try {
      final manifest = await _client.videos.streamsClient
          .getManifest(videoId, requireWatchPage: false)
          .timeout(const Duration(seconds: 5));

      final candidates = _extractCandidateUrls(manifest);
      if (candidates.isNotEmpty) {
        _cache[videoId] = StreamCacheEntry(
          candidateUrls: candidates,
          extractedAt: DateTime.now(),
        );
        return candidates;
      }
    } catch (_) {}

    /// Tier 2: Standard web client extraction.
    try {
      final manifest = await _client.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 10));

      final candidates = _extractCandidateUrls(manifest);
      if (candidates.isNotEmpty) {
        _cache[videoId] = StreamCacheEntry(
          candidateUrls: candidates,
          extractedAt: DateTime.now(),
        );
        return candidates;
      }
    } catch (_) {}

    /// Tier 3: Android client fallback.
    try {
      final manifest = await _client.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: <YoutubeApiClient>[
              YoutubeApiClient.android,
            ],
          )
          .timeout(const Duration(seconds: 10));

      final candidates = _extractCandidateUrls(manifest);
      if (candidates.isNotEmpty) {
        _cache[videoId] = StreamCacheEntry(
          candidateUrls: candidates,
          extractedAt: DateTime.now(),
        );
        return candidates;
      }
    } catch (_) {}

    return <String>[];
  }

  /// Extracts the direct audio playback URL for a YouTube video ID.
  Future<String?> getAudioStreamUrl(
    String videoId, {
    bool forceRefresh = false,
  }) async {
    final candidates = await getCandidateStreamUrls(
      videoId,
      forceRefresh: forceRefresh,
    );
    return candidates.isNotEmpty ? candidates.first : null;
  }

  /// Extracts candidate playback URLs ordered by quality and buffer responsiveness on low internet.
  List<String> _extractCandidateUrls(StreamManifest manifest) {
    final results = <String>[];

    /// 1. Prioritize fast-buffering M4A / AAC audio-only streams (itag 140 ~128kbps).
    final aacStreams = manifest.audioOnly
        .where((s) => s.container.name.toLowerCase() == 'mp4')
        .toList();
    if (aacStreams.isNotEmpty) {
      final bestAac = aacStreams.withHighestBitrate().url.toString();
      results.add(bestAac);
    }

    /// 2. Opus audio-only streams (WebM).
    final opusStreams = manifest.audioOnly
        .where((s) => s.container.name.toLowerCase() != 'mp4')
        .toList();
    if (opusStreams.isNotEmpty) {
      final bestOpus = opusStreams.withHighestBitrate().url.toString();
      if (!results.contains(bestOpus)) {
        results.add(bestOpus);
      }

      /// 3. Lightweight Opus stream (~50-70 kbps) as ultra-resilient fallback for 2G/3G low internet.
      if (opusStreams.length > 1) {
        final fastLowOpus = opusStreams.sortByBitrate().first.url.toString();
        if (!results.contains(fastLowOpus)) {
          results.add(fastLowOpus);
        }
      }
    }

    /// 4. Muxed MP4 video+audio fallback (extremely resilient against 403 errors).
    if (manifest.muxed.isNotEmpty) {
      final bestMuxed = manifest.muxed.sortByBitrate().last.url.toString();
      if (!results.contains(bestMuxed)) {
        results.add(bestMuxed);
      }
    }

    return results;
  }

  /// Closes internal network resources.
  void close() {
    _client.close();
  }
}
