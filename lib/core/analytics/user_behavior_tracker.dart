import 'dart:math';

import '../../models/song_model.dart';

/// Tracks user interaction signals, dwell duration, and engagement metrics (similar to Instagram feed algorithms).
/// Derives real-time artist, language, and song affinities to intelligently personalize feeds and smart-shuffle queues.
class UserBehaviorTracker {
  /// Artist engagement scores aggregated from dwell time, completion rates, and explicit likes.
  final Map<String, double> _artistAffinities = <String, double>{};

  /// Language engagement scores aggregated from user listening duration.
  final Map<String, double> _languageAffinities = <String, double>{};

  /// Per-song accumulated dwell and play duration in seconds.
  final Map<String, int> _songDwellTime = <String, int>{};

  /// Count of completed plays per song ID.
  final Map<String, int> _songCompletions = <String, int>{};

  /// Count of early skips per song ID (listened < 8 seconds).
  final Map<String, int> _songSkips = <String, int>{};

  /// Total play starts per song ID.
  final Map<String, int> _songPlayCounts = <String, int>{};

  /// Cache of played SongModel instances.
  final Map<String, SongModel> _playedSongModels = <String, SongModel>{};

  /// Total recorded active listening time across the entire session in seconds.
  int _totalListenSeconds = 0;

  /// Timestamp when the currently active track started playback.
  DateTime? _currentTrackStartTime;

  /// ID of the currently active track being tracked.
  String? _activeTrackId;

  /// Optional callback invoked whenever behavioral analytics or play metrics update.
  void Function()? onDataChanged;

  /// Currently active tracked song ID.
  String? get activeTrackId => _activeTrackId;

  /// Timestamp when the current track began playback.
  DateTime? get currentTrackStartTime => _currentTrackStartTime;

  /// Unmodifiable view of artist affinity scores.
  Map<String, double> get artistAffinities =>
      Map<String, double>.unmodifiable(_artistAffinities);

  /// Unmodifiable view of language affinity scores.
  Map<String, double> get languageAffinities =>
      Map<String, double>.unmodifiable(_languageAffinities);

  /// Total listening seconds accumulated.
  int get totalListenSeconds => _totalListenSeconds;

  /// Total skips recorded.
  int get totalSkips =>
      _songSkips.values.fold<int>(0, (sum, val) => sum + val);

  /// Total completed tracks recorded.
  int get totalCompletions =>
      _songCompletions.values.fold<int>(0, (sum, val) => sum + val);

  /// Unmodifiable view of song play counts.
  Map<String, int> get songPlayCounts =>
      Map<String, int>.unmodifiable(_songPlayCounts);

  /// Gets the total play count recorded for a given song ID.
  int getPlayCount(String songId) => _songPlayCounts[songId] ?? 0;

  /// Checks whether a song has been recorded as played.
  bool hasPlayedSong(String id) => _playedSongModels.containsKey(id);

  /// Registers an already played song (e.g. from history).
  void registerPlayedTrack(SongModel song, {int count = 1}) {
    _playedSongModels[song.id] = song;
    _songPlayCounts[song.id] = (_songPlayCounts[song.id] ?? 0) + count;
    onDataChanged?.call();
  }

  /// Returns songs played most by the user, ranked by play count, dwell time, completions, and likes.
  List<SongModel> getMostPlayedSongs({
    int limit = 5,
    List<SongModel>? fallbackTracks,
  }) {
    final List<SongModel> mostPlayed = _playedSongModels.values.toList();
    mostPlayed.sort((a, b) {
      final aPlays = _songPlayCounts[a.id] ?? 0;
      final bPlays = _songPlayCounts[b.id] ?? 0;
      if (aPlays != bPlays) {
        return bPlays.compareTo(aPlays);
      }
      final aDwell = _songDwellTime[a.id] ?? 0;
      final bDwell = _songDwellTime[b.id] ?? 0;
      if (aDwell != bDwell) {
        return bDwell.compareTo(aDwell);
      }
      final aComp = _songCompletions[a.id] ?? 0;
      final bComp = _songCompletions[b.id] ?? 0;
      if (aComp != bComp) {
        return bComp.compareTo(aComp);
      }
      if (a.isLiked != b.isLiked) {
        return a.isLiked ? -1 : 1;
      }
      return 0;
    });

    final Set<String> pickedIds = <String>{};
    final Set<String> pickedFps = <String>{};
    final List<SongModel> result = <SongModel>[];

    for (final song in mostPlayed) {
      final fp = SongModel.normalizeFingerprint(song.title);
      if (!pickedIds.contains(song.id) &&
          (fp.isEmpty || !pickedFps.contains(fp))) {
        result.add(song);
        pickedIds.add(song.id);
        if (fp.isNotEmpty) pickedFps.add(fp);
        if (result.length >= limit) break;
      }
    }

    /// If fewer than [limit] tracks have been played, backfill with [fallbackTracks] avoiding duplicates.
    if (result.length < limit &&
        fallbackTracks != null &&
        fallbackTracks.isNotEmpty) {
      for (final track in fallbackTracks) {
        final fp = SongModel.normalizeFingerprint(track.title);
        if (!pickedIds.contains(track.id) &&
            (fp.isEmpty || !pickedFps.contains(fp))) {
          result.add(track);
          pickedIds.add(track.id);
          if (fp.isNotEmpty) pickedFps.add(fp);
          if (result.length >= limit) break;
        }
      }
    }

    return result;
  }

  /// Records when a new song begins playback.
  void recordSongPlayStart(SongModel song) {
    _finalizePreviousTrack();
    _activeTrackId = song.id;
    _currentTrackStartTime = DateTime.now();

    _songPlayCounts[song.id] = (_songPlayCounts[song.id] ?? 0) + 1;
    _playedSongModels[song.id] = song;

    /// Initial discovery credit for selecting the track.
    _boostAffinity(song.artist, 0.5);
    onDataChanged?.call();
  }

  /// Records incremental playback duration updates.
  void recordSongPlaybackProgress(
    SongModel song,
    Duration position,
    Duration totalDuration,
  ) {
    final seconds = position.inSeconds;
    if (seconds <= 0) return;

    final currentTotal = _songDwellTime[song.id] ?? 0;
    if (seconds > currentTotal) {
      final delta = seconds - currentTotal;
      _songDwellTime[song.id] = seconds;
      _totalListenSeconds += delta;

      /// Sustained dwell time generates progressive affinity gains.
      if (seconds >= 30 && currentTotal < 30) {
        _boostAffinity(song.artist, 2.0);
      }
      if (seconds >= 60 && currentTotal < 60) {
        _boostAffinity(song.artist, 2.5);
      }
    }
  }

  /// Records when a track plays to completion.
  void recordSongCompleted(SongModel song) {
    _songCompletions[song.id] = (_songCompletions[song.id] ?? 0) + 1;

    /// Strongest implicit signal: completing full track yields massive affinity boost.
    _boostAffinity(song.artist, 6.0);
    _finalizePreviousTrack();
    onDataChanged?.call();
  }

  /// Records early skips or premature track switches.
  void recordSongSkipped(
    SongModel song,
    Duration durationListened,
    Duration totalDuration,
  ) {
    final listenedSec = durationListened.inSeconds;

    if (listenedSec < 8) {
      /// Negative engagement signal: early skip within 8s indicates disinterest.
      _songSkips[song.id] = (_songSkips[song.id] ?? 0) + 1;
      _penalizeAffinity(song.artist, 1.5);
    } else if (listenedSec >= 30) {
      /// If listened > 30s before skipping, user was engaged; give positive credit.
      _boostAffinity(song.artist, 1.5);
    }

    _finalizePreviousTrack();
    onDataChanged?.call();
  }

  /// Records explicit user actions like favorite.
  void recordExplicitAction(
    SongModel song, {
    required bool isLike,
  }) {
    if (isLike) {
      _boostAffinity(song.artist, 8.0);
    }
    onDataChanged?.call();
  }

  /// Records card dwell time when a user inspects or lingers on a track card.
  void recordCardDwellTime(SongModel song, Duration dwell) {
    final seconds = dwell.inSeconds;
    if (seconds >= 3) {
      _songDwellTime[song.id] = (_songDwellTime[song.id] ?? 0) + seconds;
      _boostAffinity(song.artist, 0.4 * seconds.clamp(1, 5));
      onDataChanged?.call();
    }
  }

  /// Registers user interaction with a specific language feed.
  void recordLanguageInteraction(String language, {double weight = 1.0}) {
    final key = language.toLowerCase();
    _languageAffinities[key] = (_languageAffinities[key] ?? 0.0) + weight;
    onDataChanged?.call();
  }

  /// Computes a personalized engagement score (0.0 to 100.0) for a given song track.
  /// Combines artist affinity, dwell duration, completion history, explicit favorites, and exploration jitter.
  double computeTrackScore(
    SongModel song, {
    String? targetLanguage,
    bool addExplorationJitter = true,
  }) {
    double score = 10.0;

    /// 1. Artist Affinity Component (Weight: ~40%).
    double artistScore = 0.0;
    final songArtistLower = song.artist.trim().toLowerCase();
    for (final entry in _artistAffinities.entries) {
      if (entry.key.isEmpty) continue;
      if (songArtistLower == entry.key ||
          songArtistLower.contains(entry.key) ||
          entry.key.contains(songArtistLower)) {
        artistScore = max(artistScore, entry.value);
      }
    }
    score += (artistScore * 2.5).clamp(0.0, 40.0);

    /// 2. Language Affinity Component (Weight: ~25%).
    if (targetLanguage != null) {
      final langKey = targetLanguage.trim().toLowerCase();
      final langScore = _languageAffinities[langKey] ?? 0.0;
      score += (langScore * 1.5).clamp(0.0, 25.0);
    }

    /// 3. Dwell & Completion History (Weight: ~20%).
    final completions = _songCompletions[song.id] ?? 0;
    final skips = _songSkips[song.id] ?? 0;
    final dwell = _songDwellTime[song.id] ?? 0;

    score += (completions * 5.0).clamp(0.0, 15.0);
    score -= (skips * 3.0).clamp(0.0, 12.0);
    score += (dwell / 15.0).clamp(0.0, 10.0);

    /// 4. Explicit Signals (Weight: ~15%).
    if (song.isLiked) score += 12.0;

    /// 5. Exploration Jitter (Instagram feed dynamism to prevent echo chambers).
    if (addExplorationJitter) {
      final random = Random();
      final jitter = (random.nextDouble() * 8.0) - 4.0;
      score += jitter;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Ranks a candidate list of songs based on predicted engagement probability.
  List<SongModel> rankTracks(
    List<SongModel> tracks, {
    String? activeLanguage,
  }) {
    if (tracks.isEmpty) return <SongModel>[];

    final scored = tracks.map((track) {
      return MapEntry<SongModel, double>(
        track,
        computeTrackScore(
          track,
          targetLanguage: activeLanguage,
          addExplorationJitter: false,
        ),
      );
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Smart Shuffle algorithm inspired by Instagram Reels recommendation flow.
  /// Interleaves high-affinity tracks with discovery items, avoiding consecutive duplicate artists.
  List<SongModel> smartShuffle(
    List<SongModel> tracks, {
    String? activeLanguage,
  }) {
    if (tracks.length <= 2) return List<SongModel>.from(tracks);

    final scored = tracks.map((track) {
      return MapEntry<SongModel, double>(
        track,
        computeTrackScore(
          track,
          targetLanguage: activeLanguage,
          addExplorationJitter: true,
        ),
      );
    }).toList();

    /// Split into high-affinity pool (top 40%) and discovery pool (remaining 60%).
    scored.sort((a, b) => b.value.compareTo(a.value));

    final splitIndex = max(1, (scored.length * 0.4).round());
    final highAffinity = scored.sublist(0, splitIndex).map((e) => e.key).toList();
    final discovery = scored.sublist(splitIndex).map((e) => e.key).toList();

    highAffinity.shuffle();
    discovery.shuffle();

    final List<SongModel> result = <SongModel>[];
    int highIndex = 0;
    int discIndex = 0;

    /// Interleave 2 high-affinity tracks with 1 discovery track for optimal retention.
    while (highIndex < highAffinity.length || discIndex < discovery.length) {
      if (highIndex < highAffinity.length) {
        result.add(highAffinity[highIndex++]);
      }
      if (highIndex < highAffinity.length) {
        result.add(highAffinity[highIndex++]);
      }
      if (discIndex < discovery.length) {
        result.add(discovery[discIndex++]);
      }
    }

    return result;
  }

  /// Generates a human-readable behavior summary for UI insights and debug profiling.
  Map<String, dynamic> getBehaviorSummary() {
    final sortedArtists = _artistAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topArtists = sortedArtists.take(3).map((e) => e.key).toList();

    final totalAttempts = totalCompletions + totalSkips;
    final skipRatePercent = totalAttempts > 0
        ? ((totalSkips / totalAttempts) * 100).toStringAsFixed(1)
        : '0.0';

    return <String, dynamic>{
      'totalListenSeconds': _totalListenSeconds,
      'totalCompletions': totalCompletions,
      'totalSkips': totalSkips,
      'skipRate': '$skipRatePercent%',
      'topArtists': topArtists,
    };
  }

  /// Increases affinity score for an artist.
  void _boostAffinity(String artist, double amount) {
    final rawArtists = artist.split(
      RegExp(r'[,&•|]|\bfeat\.?\b|\bft\.?\b', caseSensitive: false),
    );
    for (final a in rawArtists) {
      final key = a.trim().toLowerCase();
      if (key.isEmpty ||
          key == 'google music' ||
          key.contains('t-series') ||
          key.contains('sony music') ||
          key.contains('zee music') ||
          key.contains('tips') ||
          key.contains('speed records')) {
        continue;
      }
      _artistAffinities[key] = (_artistAffinities[key] ?? 0.0) + amount;
    }
  }

  /// Reduces affinity score for an artist after repeated skips.
  void _penalizeAffinity(String artist, double amount) {
    final rawArtists = artist.split(
      RegExp(r'[,&•|]|\bfeat\.?\b|\bft\.?\b', caseSensitive: false),
    );
    for (final a in rawArtists) {
      final key = a.trim().toLowerCase();
      if (key.isEmpty || key == 'google music') continue;
      final current = _artistAffinities[key] ?? 0.0;
      _artistAffinities[key] = max(0.0, current - amount);
    }
  }

  /// Finalizes the current track's dwell session.
  void _finalizePreviousTrack() {
    _activeTrackId = null;
    _currentTrackStartTime = null;
  }

  /// Exports all behavioral metrics and affinity states to a JSON-serializable map.
  Map<String, Object> toMap() {
    return <String, Object>{
      'artistAffinities': _artistAffinities,
      'languageAffinities': _languageAffinities,
      'songDwellTime': _songDwellTime,
      'songCompletions': _songCompletions,
      'songSkips': _songSkips,
      'songPlayCounts': _songPlayCounts,
      'totalListenSeconds': _totalListenSeconds,
      'playedSongModels': _playedSongModels.values
          .map((SongModel s) => s.toMap())
          .toList(),
    };
  }

  /// Restores behavioral metrics and affinity states from persisted map.
  void loadFromMap(Map<String, Object?> map) {
    try {
      final artists = map['artistAffinities'];
      if (artists is Map) {
        _artistAffinities.clear();
        artists.forEach((Object? k, Object? v) {
          if (k is String && v is num) {
            _artistAffinities[k] = v.toDouble();
          }
        });
      }

      final langs = map['languageAffinities'];
      if (langs is Map) {
        _languageAffinities.clear();
        langs.forEach((Object? k, Object? v) {
          if (k is String && v is num) {
            _languageAffinities[k] = v.toDouble();
          }
        });
      }

      final dwell = map['songDwellTime'];
      if (dwell is Map) {
        _songDwellTime.clear();
        dwell.forEach((Object? k, Object? v) {
          if (k is String && v is num) {
            _songDwellTime[k] = v.toInt();
          }
        });
      }

      final comps = map['songCompletions'];
      if (comps is Map) {
        _songCompletions.clear();
        comps.forEach((Object? k, Object? v) {
          if (k is String && v is num) {
            _songCompletions[k] = v.toInt();
          }
        });
      }

      final skips = map['songSkips'];
      if (skips is Map) {
        _songSkips.clear();
        skips.forEach((Object? k, Object? v) {
          if (k is String && v is num) {
            _songSkips[k] = v.toInt();
          }
        });
      }

      final plays = map['songPlayCounts'];
      if (plays is Map) {
        _songPlayCounts.clear();
        plays.forEach((Object? k, Object? v) {
          if (k is String && v is num) {
            _songPlayCounts[k] = v.toInt();
          }
        });
      }

      final totalSecs = map['totalListenSeconds'];
      if (totalSecs is num) {
        _totalListenSeconds = totalSecs.toInt();
      }

      final playedSongs = map['playedSongModels'];
      if (playedSongs is List) {
        _playedSongModels.clear();
        for (final item in playedSongs) {
          if (item is Map<String, dynamic>) {
            final song = SongModel.fromMap(item);
            _playedSongModels[song.id] = song;
          }
        }
      }
    } catch (_) {}
  }
}
