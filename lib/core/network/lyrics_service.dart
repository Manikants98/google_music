import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/song_model.dart';

/// Represents a timestamped lyrics line for synchronized karaoke-style playback.
class SyncedLyricLine {
  /// Playback timestamp when this line begins.
  final Duration timestamp;

  /// Text content of this lyrics line.
  final String text;

  /// Whether this line represents an instrumental music interlude.
  final bool isInstrumental;

  /// Creates a synced lyric line.
  const SyncedLyricLine({
    required this.timestamp,
    required this.text,
    this.isInstrumental = false,
  });
}

/// Lyrics data container with both synced lines and full plain text.
class LyricsData {
  /// Track title.
  final String title;

  /// Artist name.
  final String artist;

  /// Plain multiline text lyrics.
  final String? plainLyrics;

  /// Timestamped lines for karaoke highlight.
  final List<SyncedLyricLine> syncedLines;

  /// Source of the lyrics (e.g. "LRCLIB Synced" or "YouTube Music Official").
  final String source;

  /// Whether synced line timestamps are available.
  bool get hasSyncedLyrics => syncedLines.isNotEmpty;

  /// Creates lyrics data.
  const LyricsData({
    required this.title,
    required this.artist,
    this.plainLyrics,
    this.syncedLines = const <SyncedLyricLine>[],
    this.source = 'LRCLIB',
  });
}

/// Service to fetch and parse synchronized and plain lyrics with smart duration matching and YouTube Music fallback.
class LyricsService {
  /// Base LRCLIB search endpoint.
  static const String _lrclibSearchUrl = 'https://lrclib.net/api/search';

  /// YouTube Music InnerTube Next endpoint for resolving lyrics browseId.
  static const String _ytmNextUrl = 'https://music.youtube.com/youtubei/v1/next';

  /// YouTube Music InnerTube Browse endpoint for fetching official lyrics.
  static const String _ytmBrowseUrl = 'https://music.youtube.com/youtubei/v1/browse';

  /// In-memory cache keyed by song ID to prevent duplicate network calls.
  final Map<String, LyricsData?> _cache = <String, LyricsData?>{};

  /// Fetches lyrics for the given song model, prioritizing duration-verified synced lyrics then YouTube Music official lyrics.
  Future<LyricsData?> getLyrics(SongModel song) async {
    if (_cache.containsKey(song.id)) {
      return _cache[song.id];
    }

    final sanitizedTitle = SongModel.sanitizeTitle(song.title);
    final primaryTitle = _extractPrimaryTitle(sanitizedTitle);
    final primaryArtist = _extractPrimaryArtist(song.artist, sanitizedTitle);
    final targetDurationSec = song.parsedDuration?.inSeconds;

    /// Tier 1: LRCLIB with smart candidate scoring and duration verification.
    LyricsData? data = await _fetchBestLrclibMatch(
      primaryTitle,
      primaryArtist,
      targetDurationSec,
    );

    /// Tier 2: YouTube Music official verified lyrics via InnerTube WEB_REMIX client.
    data ??= await _fetchOfficialYtmLyrics(song.id, primaryTitle, primaryArtist);

    _cache[song.id] = data;
    return data;
  }

  /// Searches LRCLIB and scores every candidate based on title accuracy and song duration match.
  Future<LyricsData?> _fetchBestLrclibMatch(
    String targetTitle,
    String targetArtist,
    int? targetDurationSec,
  ) async {
    if (targetTitle.isEmpty) return null;

    final queryVariants = <String>[
      if (targetArtist.isNotEmpty) '$targetTitle $targetArtist',
      targetTitle,
    ];

    for (final q in queryVariants) {
      try {
        final uri = Uri.parse(_lrclibSearchUrl).replace(
          queryParameters: <String, String>{'q': q},
        );

        final response = await http.get(
          uri,
          headers: const <String, String>{
            'User-Agent': 'GoogleMusic/1.0 (https://github.com/google_music)',
          },
        ).timeout(const Duration(seconds: 7));

        if (response.statusCode != 200) continue;

        final dynamic decoded = json.decode(response.body);
        if (decoded is! List || decoded.isEmpty) continue;

        Map<String, dynamic>? bestCandidate;
        int highestScore = -999999;

        final normalizedTarget = targetTitle.toLowerCase().trim();

        for (final raw in decoded) {
          if (raw is! Map<String, dynamic>) continue;
          final candTitle = (raw['trackName'] ?? raw['name'] ?? '').toString().toLowerCase().trim();
          final double candDuration = (raw['duration'] as num?)?.toDouble() ?? 0.0;
          final bool hasSynced = raw['syncedLyrics'] != null;

          int score = 0;

          /// 1. Exact or partial title scoring.
          if (candTitle == normalizedTarget) {
            score += 100;
          } else if (candTitle.startsWith(normalizedTarget)) {
            final remainder = candTitle.substring(normalizedTarget.length).trim();
            /// Penalize sequels like "Aaj Bhi 2" or remixes if target is not a remix.
            if (RegExp(r'^(2|ii|3|part|remix|lofi|slowed|reverb)', caseSensitive: false).hasMatch(remainder)) {
              score -= 500;
            } else {
              score += 30;
            }
          } else {
            score -= 50;
          }

          /// 2. Duration proximity scoring (crucial for YouTube music videos).
          if (targetDurationSec != null && candDuration > 0) {
            final diff = (candDuration - targetDurationSec).abs().round();
            if (diff <= 6) {
              score += 85;
            } else if (diff <= 15) {
              score += 45;
            } else if (diff <= 28) {
              score += 15;
            } else {
              score -= 60;
            }
          }

          /// 3. Prefer synchronized lyrics.
          if (hasSynced) {
            score += 30;
          }

          if (score > highestScore) {
            highestScore = score;
            bestCandidate = raw;
          }
        }

        if (bestCandidate != null && highestScore >= 60) {
          final parsed = _parseLyricsJson(bestCandidate, 'LRCLIB Synced');
          if (parsed != null) {
            return parsed;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Fetches official lyrics directly from YouTube Music's InnerTube API.
  Future<LyricsData?> _fetchOfficialYtmLyrics(
    String videoId,
    String fallbackTitle,
    String fallbackArtist,
  ) async {
    if (videoId.isEmpty) return null;

    try {
      final clientContext = <String, dynamic>{
        'client': <String, dynamic>{
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20230522.01.00',
          'hl': 'en',
          'gl': 'IN',
        },
      };

      /// Step 1: Resolve lyrics browseId from watch next results.
      final nextResponse = await http.post(
        Uri.parse(_ytmNextUrl),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        },
        body: json.encode(<String, dynamic>{
          'context': clientContext,
          'videoId': videoId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (nextResponse.statusCode != 200) return null;

      final dynamic nextDecoded = json.decode(nextResponse.body);
      final tabs = nextDecoded['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs'];

      String? lyricsBrowseId;
      if (tabs is List) {
        for (final t in tabs) {
          final tabRenderer = t['tabRenderer'];
          final tabTitle = tabRenderer?['title']?.toString().toLowerCase();
          final browseId = tabRenderer?['endpoint']?['browseEndpoint']?['browseId'];
          if (tabTitle == 'lyrics' && browseId != null) {
            lyricsBrowseId = browseId.toString();
            break;
          }
        }
      }

      if (lyricsBrowseId == null || lyricsBrowseId.isEmpty) return null;

      /// Step 2: Fetch official lyrics text from browse endpoint.
      final browseResponse = await http.post(
        Uri.parse(_ytmBrowseUrl),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        },
        body: json.encode(<String, dynamic>{
          'context': clientContext,
          'browseId': lyricsBrowseId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (browseResponse.statusCode != 200) return null;

      final dynamic browseDecoded = json.decode(browseResponse.body);
      final descShelf = browseDecoded['contents']?['sectionListRenderer']?['contents']?[0]?['musicDescriptionShelfRenderer'];
      final runs = descShelf?['description']?['runs'];

      if (runs is List && runs.isNotEmpty) {
        final text = runs.map((r) => r['text'] ?? '').join();
        if (text.trim().isNotEmpty) {
          return LyricsData(
            title: fallbackTitle,
            artist: fallbackArtist,
            plainLyrics: text.trim(),
            source: 'YouTube Music Official',
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Parses JSON payload from LRCLIB into a LyricsData model.
  LyricsData? _parseLyricsJson(Map<String, dynamic> json, String source) {
    final trackName = (json['trackName'] ?? json['name'] ?? '').toString();
    final artistName = (json['artistName'] ?? '').toString();
    final plain = json['plainLyrics']?.toString();
    final synced = json['syncedLyrics']?.toString();

    final List<SyncedLyricLine> syncedLines = <SyncedLyricLine>[];
    if (synced != null && synced.trim().isNotEmpty) {
      final lines = synced.split('\n');
      final regExp = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\](.*)$');
      for (final raw in lines) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        final match = regExp.firstMatch(trimmed);
        if (match != null) {
          final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
          final secondsDouble = double.tryParse(match.group(2) ?? '0') ?? 0.0;
          final totalMs = (minutes * 60 * 1000 + (secondsDouble * 1000)).round();
          final text = (match.group(3) ?? '').trim();
          syncedLines.add(
            SyncedLyricLine(
              timestamp: Duration(milliseconds: totalMs),
              text: text.isEmpty ? '♪  ♪  ♪' : text,
              isInstrumental: text.isEmpty,
            ),
          );
        }
      }
    }

    if (syncedLines.isEmpty && (plain == null || plain.trim().isEmpty)) {
      return null;
    }

    return LyricsData(
      title: trackName,
      artist: artistName,
      plainLyrics: plain,
      syncedLines: syncedLines,
      source: source,
    );
  }

  /// Extracts the song's primary title candidate from YouTube composite titles.
  String _extractPrimaryTitle(String title) {
    final tokens = title.split(RegExp(r'[|\-–—:]'));
    if (tokens.isNotEmpty) {
      final first = tokens[0].trim();
      /// Strip singer name if attached directly to song title like "Aaj Bhi Vishal Mishra".
      final clean = first.replaceAll(
        RegExp(r'\b(vishal mishra|arijit singh|shreya ghoshal|neha kakkar|badshah|diljit dosanjh|jubin nautiyal|atif aslam)\b', caseSensitive: false),
        '',
      ).trim();
      if (clean.isNotEmpty) {
        return clean;
      }
      return first;
    }
    return title.trim();
  }

  /// Extracts the singer/artist from artist channel or composite title.
  String _extractPrimaryArtist(String rawArtist, String title) {
    final cleanArtist = SongModel.sanitizeArtist(rawArtist);
    const labels = <String>[
      't-series',
      'sony music',
      'zee music',
      'yrf',
      'tips',
      'speed records',
      'white hill',
      'saregama',
      'geet mp3',
      'desimelodies',
      'dm - desi melodies',
      'warnermusic',
      'universal music',
      'vyrloriginals',
      'vyrl originals',
    ];

    final lower = cleanArtist.toLowerCase();
    for (final label in labels) {
      if (lower.contains(label)) {
        /// If channel is a record label, search for artist inside the title.
        final artistMatch = RegExp(
          r'\b(vishal mishra|arijit singh|shreya ghoshal|neha kakkar|badshah|diljit dosanjh|jubin nautiyal|atif aslam|anirudh|armaan malik|amaal mallik|darshan raval|b praak|sunidhi chauhan)\b',
          caseSensitive: false,
        ).firstMatch(title);
        if (artistMatch != null) {
          return artistMatch.group(0) ?? '';
        }

        final tokens = title.split(RegExp(r'[|\-–—:]'));
        if (tokens.length > 1) {
          final second = tokens[1].trim();
          if (second.isNotEmpty) {
            return second;
          }
        }
        return '';
      }
    }
    return cleanArtist;
  }
}
