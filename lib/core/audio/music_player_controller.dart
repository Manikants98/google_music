import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/playback_state.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../analytics/user_behavior_tracker.dart';
import '../network/innertube_client.dart';
import '../network/lyrics_service.dart';
import '../offline/download_notification_service.dart';
import '../offline/offline_download_service.dart';
import '../playlist/playlist_service.dart';
import 'music_audio_handler.dart';
import 'stream_extractor.dart';

/// Central controller managing playback state, queue orchestration, and dynamic art theming.
class MusicPlayerController extends ChangeNotifier {
  /// Native audio streaming engine with custom desktop User-Agent to bypass YouTube 403 restrictions.
  final ja.AudioPlayer _player = ja.AudioPlayer(
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    useProxyForRequestHeaders: false,
  );

  /// Extractor service for YouTube streams.
  final AudioStreamExtractor _extractor = AudioStreamExtractor();

  /// InnerTube client for search and recommendations.
  final InnerTubeClient innerTubeClient = InnerTubeClient();

  /// Service for fetching synchronized and plain lyrics.
  final LyricsService lyricsService = LyricsService();

  /// User dwell and engagement behavior analytics tracker.
  final UserBehaviorTracker behaviorTracker = UserBehaviorTracker();

  /// Background audio handler.
  final GoogleMusicAudioHandler? audioHandler;

  /// Subscription to player state changes.
  StreamSubscription<ja.PlayerState>? _playerSubscription;

  /// Monotonic session counter to prevent race conditions during rapid track switching.
  int _sessionToken = 0;

  /// Currently loaded song track.
  SongModel? _currentSong;

  /// Active track queue.
  List<SongModel> _queue = <SongModel>[];

  /// Index of currently playing track in queue.
  int _currentIndex = -1;

  /// Operational playback status.
  PlayerStatus _status = PlayerStatus.idle;

  /// Loop mode setting.
  LoopMode _loopMode = LoopMode.off;

  /// Whether shuffle playback is enabled.
  bool _isShuffle = false;

  /// Dynamic primary seed color extracted from current album art.
  Color _dynamicAccentColor = const Color(0xFFFF4E4E);

  /// Dynamic background gradient colors.
  List<Color> _dynamicGradient = const <Color>[
    Color(0xFF1E2028),
    Color(0xFF0F0F13),
  ];

  /// Active application theme mode.
  ThemeMode _themeMode = ThemeMode.system;

  /// Liked songs list.
  final List<SongModel> _likedSongs = <SongModel>[];

  /// Playback history.
  final List<SongModel> _history = <SongModel>[];

  /// Storage file handle for persisting liked songs.
  File? _likedSongsFile;

  /// Storage file handle for persisting listening history.
  File? _historyFile;

  /// Storage file handle for persisting behavioral analytics.
  File? _behaviorFile;

  /// Storage file handle for persisting general app settings.
  File? _settingsFile;

  /// Debounce timer for saving behavioral analytics to reduce unnecessary disk writes.
  Timer? _behaviorDebounceTimer;

  /// Flag indicating whether persistent user data has completed loading.
  bool _isUserDataLoaded = false;

  /// Whether persistent user data has completed loading from disk.
  bool get isUserDataLoaded => _isUserDataLoaded;

  /// Current playback position.
  Duration _position = Duration.zero;

  /// Total duration of currently active track.
  Duration _duration = Duration.zero;

  /// Buffered duration.
  Duration _bufferedPosition = Duration.zero;

  /// Fine-grained playback position notifier for UI seekbars without rebuilding entire widget trees.
  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);

  /// Fine-grained buffered duration notifier for UI progress indicators without rebuilding entire widget trees.
  final ValueNotifier<Duration> bufferedPositionNotifier =
      ValueNotifier<Duration>(Duration.zero);

  /// Error message when playback fails.
  String? _errorMessage;

  /// Whether an autoplay recommendation fetch is currently in flight.
  bool _isFetchingAutoplay = false;

  /// Whether current playback queue is bound strictly to a playlist without autoplay expansion.
  bool _isPlaylistQueue = false;

  /// Whether autoplay continuous recommendation is enabled.
  bool _isAutoplayEnabled = true;

  /// Backing instance for offline download service.
  OfflineDownloadService? _offlineService;

  /// Service managing offline song downloads and storage.
  OfflineDownloadService get offlineService {
    if (_offlineService == null) {
      final s = OfflineDownloadService();
      _offlineService = s;
      unawaited(s.initialize());
      s.addListener(notifyListeners);
    }
    _initOfflineServiceCallbacks();
    return _offlineService!;
  }

  /// Backing instance for playlist service.
  PlaylistService? _playlistService;

  /// Service managing custom user playlists and persistence.
  PlaylistService get playlistService {
    if (_playlistService == null) {
      final p = PlaylistService();
      _playlistService = p;
      unawaited(p.initialize());
      p.addListener(notifyListeners);
    }
    return _playlistService!;
  }

  /// Creates music player controller and wires audio handler events.
  MusicPlayerController({
    this.audioHandler,
    OfflineDownloadService? offlineService,
    PlaylistService? playlistService,
  }) {
    _offlineService = offlineService;
    _playlistService = playlistService;
    _initHandlerCallbacks();
    _initPlayerListeners();
    _initOfflineServiceCallbacks();
    this.offlineService.addListener(notifyListeners);
    this.playlistService.addListener(notifyListeners);
    unawaited(initialize());
  }

  /// Initializes controller by loading all persisted user data from disk.
  Future<void> initialize() async {
    if (_isUserDataLoaded) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _likedSongsFile = File('${docDir.path}/liked_songs.json');
      _historyFile = File('${docDir.path}/playback_history.json');
      _behaviorFile = File('${docDir.path}/user_behavior.json');
      _settingsFile = File('${docDir.path}/app_settings.json');

      await Future.wait<void>(<Future<void>>[
        _loadLikedSongs(),
        _loadHistory(),
        _loadBehavior(),
        _loadSettings(),
      ]);

      behaviorTracker.onDataChanged = _queuePersistBehavior;
      _isUserDataLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicPlayerController] Initialization error: $e');
    }
  }

  /// Current song track.
  SongModel? get currentSong => _currentSong;

  /// Active queue of songs.
  List<SongModel> get queue => List<SongModel>.unmodifiable(_queue);

  /// Current index in queue.
  int get currentIndex => _currentIndex;

  /// Player operational status.
  PlayerStatus get status => _status;

  /// Loop mode.
  LoopMode get loopMode => _loopMode;

  /// Whether shuffle is enabled.
  bool get isShuffle => _isShuffle;

  /// Whether an autoplay recommendation fetch is currently in flight.
  bool get isFetchingAutoplay => _isFetchingAutoplay;

  /// Whether current playback queue is strictly bounded to a playlist.
  bool get isPlaylistQueue => _isPlaylistQueue;

  /// Dynamic accent color.
  Color get dynamicAccentColor => _dynamicAccentColor;

  /// Returns a calibrated accent color with guaranteed WCAG contrast against light or dark surfaces.
  Color getLegibleAccentColor(bool isDark) {
    final hsl = HSLColor.fromColor(_dynamicAccentColor);
    if (isDark) {
      final lightness = hsl.lightness < 0.60 ? 0.65 : hsl.lightness.clamp(0.60, 0.88);
      final saturation = hsl.saturation < 0.55 ? 0.65 : hsl.saturation;
      return hsl.withLightness(lightness).withSaturation(saturation).toColor();
    } else {
      final lightness = hsl.lightness > 0.40 ? 0.35 : hsl.lightness.clamp(0.20, 0.40);
      final saturation = hsl.saturation < 0.65 ? 0.75 : hsl.saturation;
      return hsl.withLightness(lightness).withSaturation(saturation).toColor();
    }
  }

  /// Dynamic gradient colors for immersive player background.
  List<Color> get dynamicGradient => _dynamicGradient;

  /// Returns light or dark dynamic gradient based on active brightness.
  List<Color> getDynamicGradient(bool isDark) {
    if (isDark) {
      return _dynamicGradient;
    }
    return <Color>[
      Color.alphaBlend(
        _dynamicAccentColor.withValues(alpha: 0.16),
        const Color(0xFFFFFFFF),
      ),
      Color.alphaBlend(
        _dynamicAccentColor.withValues(alpha: 0.05),
        const Color(0xFFF4F5F9),
      ),
    ];
  }

  /// Current theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Sets the application theme mode and persists choice.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      unawaited(_persistSettings());
      notifyListeners();
    }
  }

  /// Toggles between light and dark theme mode based on context brightness and persists choice.
  void toggleThemeMode(BuildContext context) {
    final currentIsDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    _themeMode = currentIsDark ? ThemeMode.light : ThemeMode.dark;
    unawaited(_persistSettings());
    notifyListeners();
  }

  /// Whether autoplay continuous recommendation is enabled.
  bool get isAutoplayEnabled => _isAutoplayEnabled;

  /// Sets autoplay continuous playback mode and persists choice.
  void setAutoplayEnabled(bool enabled) {
    if (_isAutoplayEnabled != enabled) {
      _isAutoplayEnabled = enabled;
      unawaited(_persistSettings());
      notifyListeners();
    }
  }

  /// Clears playback history and persists empty state.
  void clearHistory() {
    _history.clear();
    unawaited(_persistHistory());
    notifyListeners();
  }

  /// Checks whether a track is present in the persistent liked songs library.
  bool isSongLiked(String songId) {
    return _likedSongs.any((SongModel s) => s.id == songId);
  }

  /// Clears in-memory stream extractor cache and refreshes state.
  void clearStreamCache() {
    _extractor.clearCache();
    notifyListeners();
  }

  /// Liked songs list.
  List<SongModel> get likedSongs => List<SongModel>.unmodifiable(_likedSongs);

  /// Playback history.
  List<SongModel> get history => List<SongModel>.unmodifiable(_history);

  /// Returns the user's most played songs for Speed Dials.
  List<SongModel> getSpeedDialSongs({
    int limit = 5,
    List<SongModel>? fallbackTracks,
  }) {
    for (final song in _likedSongs) {
      if (!behaviorTracker.hasPlayedSong(song.id)) {
        behaviorTracker.registerPlayedTrack(song, count: 2);
      }
    }
    for (final song in _history) {
      if (!behaviorTracker.hasPlayedSong(song.id)) {
        behaviorTracker.registerPlayedTrack(song);
      }
    }
    return behaviorTracker.getMostPlayedSongs(
      limit: limit,
      fallbackTracks: fallbackTracks,
    );
  }

  /// Current position.
  Duration get position => _position;

  /// Total track duration. Falls back to song metadata duration if player stream duration is not yet resolved.
  Duration get duration {
    if (_duration > Duration.zero) {
      return _duration;
    }
    return _currentSong?.parsedDuration ?? Duration.zero;
  }

  /// Buffered position.
  Duration get bufferedPosition => _bufferedPosition;

  /// Error message if any.
  String? get errorMessage => _errorMessage;

  /// Whether a song is currently playing.
  bool get isPlaying => _status == PlayerStatus.playing;

  /// Connects audio handler events to controller methods.
  void _initHandlerCallbacks() {
    if (audioHandler == null) return;
    audioHandler!.onPlay = resume;
    audioHandler!.onPause = pause;
    audioHandler!.onSkipToNext = playNext;
    audioHandler!.onSkipToPrevious = playPrevious;
    audioHandler!.onSeek = seek;
    audioHandler!.onStop = pause;
  }

  /// Wires offline download service callbacks for separate native download notifications.
  void _initOfflineServiceCallbacks() {
    final s = _offlineService;
    if (s == null) return;
    s.onDownloadProgressUpdated =
        (SongModel song, int percent, bool isComplete) {
      if (isComplete) {
        DownloadNotificationService.showComplete(
          id: song.id,
          title: song.title,
        );
      } else {
        DownloadNotificationService.showProgress(
          id: song.id,
          title: song.title,
          percent: percent,
        );
      }
    };

    s.onDownloadCancelled = (SongModel song) {
      DownloadNotificationService.cancel(id: song.id);
    };

    s.onAllDownloadsFinished = () {
      DownloadNotificationService.cancelAll();
    };
  }

  /// Listens to internal player stream updates.
  void _initPlayerListeners() {
    _playerSubscription = _player.playerStateStream.listen((state) {
      if (_status == PlayerStatus.loading) {
        if (state.processingState == ja.ProcessingState.ready) {
          _status = state.playing ? PlayerStatus.playing : PlayerStatus.paused;
          _syncAudioNotification();
          notifyListeners();
        }
        return;
      }

      switch (state.processingState) {
        case ja.ProcessingState.idle:
          _status = PlayerStatus.idle;
          break;
        case ja.ProcessingState.loading:
        case ja.ProcessingState.buffering:
          _status = PlayerStatus.loading;
          break;
        case ja.ProcessingState.ready:
          _status = state.playing ? PlayerStatus.playing : PlayerStatus.paused;
          break;
        case ja.ProcessingState.completed:
          _onTrackCompleted();
          break;
      }
      _syncAudioNotification();
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      positionNotifier.value = pos;
      if (_duration == Duration.zero && _currentSong?.parsedDuration != null) {
        _duration = _currentSong!.parsedDuration!;
      }
      if (_currentSong != null) {
        behaviorTracker.recordSongPlaybackProgress(
          _currentSong!,
          pos,
          duration,
        );
      }
      if (pos.inSeconds > 0 && pos.inSeconds % 5 == 0) {
        _syncAudioNotification();
      }
      if (_duration > Duration.zero &&
          (_duration - pos).inSeconds <= 35 &&
          pos.inSeconds % 10 == 0) {
        if (!_isPlaylistQueue) {
          unawaited(ensureAutoplayQueue());
        }
        _prefetchUpcomingStreams();
      }
      /// Note: Position ticks only notify positionNotifier listeners.
      /// We avoid broadcast notifyListeners() to prevent re-rendering the entire app 5-10 times/second.
    });

    _player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
        if (_currentSong != null) {
          audioHandler?.setTrackMetadata(
            id: _currentSong!.id,
            title: _currentSong!.title,
            artist: _currentSong!.artist,
            artUri: _currentSong!.thumbnailUrl,
            duration: dur,
          );
        }
        _syncAudioNotification();
        notifyListeners();
      }
    });

    _player.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      bufferedPositionNotifier.value = buf;
    });
  }

  /// Handles automatic track advancement upon completion.
  void _onTrackCompleted() async {
    if (_currentSong != null) {
      behaviorTracker.recordSongCompleted(_currentSong!);
    }

    if (_loopMode == LoopMode.one) {
      await seek(Duration.zero);
      await resume();
      return;
    }

    if (_currentIndex + 1 >= _queue.length && _loopMode != LoopMode.all) {
      if (!_isPlaylistQueue) {
        await ensureAutoplayQueue(force: true);
      }
    }

    if (_currentIndex + 1 < _queue.length || _loopMode == LoopMode.all) {
      await playNext();
    } else {
      _status = PlayerStatus.paused;
      await seek(Duration.zero);
      _syncAudioNotification();
      notifyListeners();
    }
  }

  /// Plays a given song with monotonic token verification to prevent track mismatch.
  Future<void> playSong(
    SongModel song, {
    List<SongModel>? newQueue,
    bool? isPlaylistQueue,
  }) async {
    final currentSession = ++_sessionToken;

    if (isPlaylistQueue != null) {
      _isPlaylistQueue = isPlaylistQueue;
    } else if (newQueue != null) {
      _isPlaylistQueue = false;
    }

    /// Register early skip if active track was interrupted during playback.
    if (_currentSong != null && _position > Duration.zero) {
      behaviorTracker.recordSongSkipped(_currentSong!, _position, _duration);
    }
    behaviorTracker.recordSongPlayStart(song);

    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List<SongModel>.from(newQueue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else if (_queue.isEmpty) {
      _queue = <SongModel>[song];
      _currentIndex = 0;
    } else {
      final existingIndex = _queue.indexWhere((s) => s.id == song.id);
      if (existingIndex != -1) {
        _currentIndex = existingIndex;
      } else {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      }
    }

    song.isLiked = isSongLiked(song.id);
    _currentSong = song;
    _history.removeWhere((s) => s.id == song.id);
    _history.insert(0, song);
    if (_history.length > 150) {
      _history.removeRange(150, _history.length);
    }
    unawaited(_persistHistory());

    _status = PlayerStatus.loading;
    _errorMessage = null;
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;
    _bufferedPosition = Duration.zero;
    bufferedPositionNotifier.value = Duration.zero;
    _duration = song.parsedDuration ?? Duration.zero;
    notifyListeners();

    audioHandler?.setTrackMetadata(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri: song.thumbnailUrl,
      duration: _duration > Duration.zero ? _duration : null,
    );
    _syncAudioNotification();
    _extractDynamicColors(song.thumbnailUrl);

    try {
      await _player.stop();

      bool loadedSuccessfully = false;
      Object? lastError;

      /// Check if track has been downloaded for instant offline playback.
      if (offlineService.isDownloaded(song.id)) {
        final localPath = offlineService.getLocalAudioPath(song.id);
        if (localPath != null && File(localPath).existsSync()) {
          try {
            final audioSource = ja.AudioSource.file(localPath);
            await _player.setAudioSource(audioSource, preload: true);
            loadedSuccessfully = true;
          } catch (offlineErr) {
            debugPrint('[MusicPlayer] Local file playback failed: $offlineErr');
          }
        }
      }

      if (!loadedSuccessfully) {
        List<String> candidates;
        if (song.audioStreamUrl != null && song.audioStreamUrl!.isNotEmpty) {
          candidates = <String>[song.audioStreamUrl!];
        } else {
          candidates = await _extractor.getCandidateStreamUrls(song.id);
        }

        if (currentSession != _sessionToken) {
          return;
        }

        if (candidates.isEmpty) {
          _status = PlayerStatus.error;
          _errorMessage = 'Could not load audio stream.';
          notifyListeners();
          return;
        }

        for (final candidateUrl in candidates) {
          try {
            final audioSource = ja.AudioSource.uri(
              Uri.parse(candidateUrl),
              headers: const <String, String>{
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
                'Referer': 'https://www.youtube.com/',
              },
            );
            await _player.setAudioSource(audioSource, preload: true);
            song.audioStreamUrl = candidateUrl;
            loadedSuccessfully = true;
            break;
          } catch (candidateErr) {
            lastError = candidateErr;
            debugPrint(
              '[MusicPlayer] Candidate stream $candidateUrl failed: $candidateErr. Trying fallback...',
            );
          }
        }
      }

      if (!loadedSuccessfully) {
        /// If cached stream URL expires or gives 403, invalidate cache and re-extract fresh candidates.
        _extractor.invalidate(song.id);
        song.audioStreamUrl = null;
        final freshCandidates = await _extractor.getCandidateStreamUrls(
          song.id,
          forceRefresh: true,
        );
        if (currentSession != _sessionToken) return;

        for (final freshUrl in freshCandidates) {
          try {
            final freshSource = ja.AudioSource.uri(
              Uri.parse(freshUrl),
              headers: const <String, String>{
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
                'Referer': 'https://www.youtube.com/',
              },
            );
            await _player.setAudioSource(freshSource, preload: true);
            song.audioStreamUrl = freshUrl;
            loadedSuccessfully = true;
            break;
          } catch (freshErr) {
            lastError = freshErr;
          }
        }
      }

      if (currentSession != _sessionToken) {
        return;
      }

      if (!loadedSuccessfully) {
        throw lastError ?? Exception('All audio streams failed to load.');
      }

      await _player.play();
      _status = PlayerStatus.playing;
      _syncAudioNotification();
      notifyListeners();
      unawaited(ensureAutoplayQueue());
      _prefetchUpcomingStreams();
    } catch (e) {
      if (currentSession != _sessionToken) return;
      _status = PlayerStatus.error;
      _errorMessage = 'Playback failure: $e';
      notifyListeners();
    }
  }

  /// Toggles play / pause state.
  Future<void> togglePlayPause() async {
    if (_status == PlayerStatus.playing) {
      await pause();
    } else if (_status == PlayerStatus.paused) {
      await resume();
    } else if (_currentSong != null) {
      await playSong(_currentSong!);
    }
  }

  /// Resumes playback.
  Future<void> resume() async {
    await _player.play();
    _status = PlayerStatus.playing;
    _syncAudioNotification();
    notifyListeners();
  }

  /// Pauses playback.
  Future<void> pause() async {
    await _player.pause();
    _status = PlayerStatus.paused;
    _syncAudioNotification();
    notifyListeners();
  }

  /// Plays next track in queue. Automatically fetches more similar tracks if near the end.
  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex + 1 < _queue.length) {
      await playSong(_queue[_currentIndex + 1]);
    } else {
      if (!_isPlaylistQueue) {
        await ensureAutoplayQueue(force: true);
      }
      if (_currentIndex + 1 < _queue.length) {
        await playSong(_queue[_currentIndex + 1]);
      } else if (_loopMode == LoopMode.all) {
        await playSong(_queue.first);
      }
    }
  }

  /// Plays previous track or restarts current track if elapsed past 3 seconds.
  Future<void> playPrevious() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_queue.isEmpty) return;
    if (_currentIndex > 0) {
      await playSong(_queue[_currentIndex - 1]);
    } else if (_loopMode == LoopMode.all) {
      await playSong(_queue.last);
    }
  }

  /// Seeks to a specific playback position.
  Future<void> seek(Duration target) async {
    _position = target;
    positionNotifier.value = target;
    _syncAudioNotification();
    notifyListeners();
    await _player.seek(target);
    _syncAudioNotification();
  }

  /// Cycles through repeat modes: off -> all -> one -> off.
  void cycleRepeatMode() {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.off;
        break;
    }
    notifyListeners();
  }

  /// Toggles shuffle mode.
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _currentSong != null) {
      final current = _currentSong!;
      final others = _queue.where((s) => s.id != current.id).toList();
      others.shuffle();
      _queue = <SongModel>[current, ...others];
      _currentIndex = 0;
    }
    notifyListeners();
  }

  /// Toggles liked status for a track and persists updated library to disk.
  void toggleLike(SongModel song) {
    final idx = _likedSongs.indexWhere((s) => s.id == song.id);
    if (idx != -1) {
      _likedSongs.removeAt(idx);
      song.isLiked = false;
    } else {
      song.isLiked = true;
      _likedSongs.insert(0, song);
    }
    behaviorTracker.recordExplicitAction(
      song,
      isLike: song.isLiked,
    );
    unawaited(_persistLikedSongs());
    notifyListeners();
  }

  /// Returns personalized ranking for candidate tracks using behavioral dwell analytics.
  List<SongModel> getPersonalizedTracks(
    List<SongModel> tracks, {
    String? language,
  }) {
    return behaviorTracker.rankTracks(tracks, activeLanguage: language);
  }

  /// Returns Instagram-style smart shuffle interleaving high-affinity tracks with discovery.
  List<SongModel> smartShuffleTracks(
    List<SongModel> tracks, {
    String? language,
  }) {
    return behaviorTracker.smartShuffle(tracks, activeLanguage: language);
  }

  /// Instantly queues up and starts playing a smart personalized mix tailored to user behavior.
  Future<void> playSmartPersonalizedQueue(
    List<SongModel> candidateTracks, {
    String? language,
  }) async {
    if (candidateTracks.isEmpty) return;
    final smartQueue = behaviorTracker.smartShuffle(
      candidateTracks,
      activeLanguage: language,
    );
    await playSong(smartQueue.first, newQueue: smartQueue);
  }

  /// Reorders items in current queue.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (_currentSong != null) {
      _currentIndex = _queue.indexWhere((s) => s.id == _currentSong!.id);
    }
    notifyListeners();
  }

  /// Removes an item from the queue with active playback and index preservation.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    if (index == _currentIndex) {
      if (_queue.length > 1) {
        if (_currentIndex + 1 < _queue.length) {
          final nextSong = _queue[_currentIndex + 1];
          _queue.removeAt(index);
          playSong(nextSong);
        } else {
          final prevSong = _queue[_currentIndex - 1];
          _queue.removeAt(index);
          _currentIndex = _queue.length - 1;
          playSong(prevSong);
        }
      } else {
        _queue.clear();
        _currentSong = null;
        _currentIndex = -1;
        _player.stop();
        _status = PlayerStatus.idle;
      }
    } else {
      _queue.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      }
    }

    if (_queue.length - 1 - _currentIndex <= 3) {
      unawaited(ensureAutoplayQueue());
    }

    notifyListeners();
  }

  /// Cleans raw title by stripping movie tags, video tags, audio labels, and featured artists.
  static String _cleanSongTitle(String title) {
    var cleaned = title;
    cleaned = cleaned.split('|').first;
    cleaned = cleaned.split(':').last;
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?\)'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'(8k|4k|hd|official|audio|video|lyric.*)', caseSensitive: false),
      '',
    );
    final trimmed = cleaned.trim();
    return trimmed.isNotEmpty ? trimmed : title;
  }

  /// Cleans raw artist name by stripping record labels and channel suffixes.
  static String _cleanArtistName(String artist) {
    var cleaned = artist;
    cleaned = cleaned.split('•').first;
    cleaned = cleaned.split(',').first;
    cleaned = cleaned.split('&').first;
    cleaned = cleaned.replaceAll(
      RegExp(r'(vevo|records|channel|music|series)', caseSensitive: false),
      '',
    );
    final trimmed = cleaned.trim();
    return trimmed.isNotEmpty ? trimmed : artist;
  }

  /// Ensures the queue has enough upcoming similar tracks for endless continuous playback.
  Future<void> ensureAutoplayQueue({bool force = false}) async {
    /// In playlist queue mode, strictly respect playlist boundary without autoplay expansion.
    if (_isPlaylistQueue) return;
    if (!_isAutoplayEnabled && !force) return;
    if (_isFetchingAutoplay) return;

    /// Calculate remaining tracks ahead of the current track.
    final remaining = _queue.length - 1 - _currentIndex;
    if (!force && remaining > 4) {
      return;
    }

    _isFetchingAutoplay = true;
    notifyListeners();

    try {
      /// Seed strictly from the active track or currently playing track.
      final seedSong = _currentSong ??
          ((_currentIndex >= 0 && _currentIndex < _queue.length)
              ? _queue[_currentIndex]
              : (_queue.isNotEmpty ? _queue.first : null));
      if (seedSong == null) {
        _isFetchingAutoplay = false;
        notifyListeners();
        return;
      }

      /// 1. Primary: Use YouTube's official watch-next recommendation engine.
      List<SongModel> candidates =
          await innerTubeClient.getWatchNextRecommendations(seedSong.id);

      /// 2. Fallback: If watch-next returned fewer than 6, search specifically by seed artist and title.
      if (candidates.length < 6) {
        final cleanTitle = _cleanSongTitle(seedSong.title);
        final cleanArtist = _cleanArtistName(seedSong.artist);

        final query1 = '$cleanTitle $cleanArtist song';
        final query2 = '$cleanArtist best hit songs';

        final candidateBatches = await Future.wait<List<SongModel>>(
          <Future<List<SongModel>>>[
            innerTubeClient.search(query1),
            innerTubeClient.search(query2),
          ],
        );

        for (final batch in candidateBatches) {
          candidates.addAll(batch);
        }
      }

      /// Deduplicate against current queue and playback history.
      final existingIds = _queue.map((s) => s.id).toSet();
      final existingFps = _queue
          .map((s) => SongModel.normalizeFingerprint(s.title))
          .toSet();

      for (final h in _history) {
        existingIds.add(h.id);
        final fp = SongModel.normalizeFingerprint(h.title);
        if (fp.isNotEmpty) {
          existingFps.add(fp);
        }
      }

      final List<SongModel> freshTracks = <SongModel>[];
      for (final candidate in candidates) {
        if (existingIds.contains(candidate.id)) continue;
        final fp = SongModel.normalizeFingerprint(candidate.title);
        if (fp.isNotEmpty && existingFps.contains(fp)) continue;

        freshTracks.add(candidate);
        existingIds.add(candidate.id);
        if (fp.isNotEmpty) {
          existingFps.add(fp);
        }

        if (freshTracks.length >= 15) break;
      }

      if (freshTracks.isNotEmpty) {
        _queue.addAll(freshTracks);
        _prefetchUpcomingStreams();
      }
    } catch (e) {
      debugPrint('[Autoplay] Failed to fetch similar tracks: $e');
    } finally {
      _isFetchingAutoplay = false;
      notifyListeners();
    }
  }

  /// Silently pre-fetches and caches direct stream URLs for upcoming tracks in queue.
  void _prefetchUpcomingStreams() {
    if (_queue.isEmpty) return;
    final nextIndex = _currentIndex + 1;
    final count = min(2, _queue.length - nextIndex);
    for (int i = 0; i < count; i++) {
      final upcomingSong = _queue[nextIndex + i];
      if (upcomingSong.audioStreamUrl == null ||
          upcomingSong.audioStreamUrl!.isEmpty) {
        unawaited(_extractor.prefetch(upcomingSong.id));
      }
    }
  }

  /// Synchronizes background system audio notification state.
  void _syncAudioNotification() {
    if (audioHandler == null) return;

    AudioProcessingState processing;
    switch (_status) {
      case PlayerStatus.idle:
        processing = AudioProcessingState.idle;
        break;
      case PlayerStatus.loading:
        processing = AudioProcessingState.loading;
        break;
      case PlayerStatus.playing:
      case PlayerStatus.paused:
        processing = AudioProcessingState.ready;
        break;
      case PlayerStatus.error:
        processing = AudioProcessingState.error;
        break;
    }

    audioHandler!.updateState(
      isPlaying: _status == PlayerStatus.playing,
      processingState: processing,
      position: _position,
      bufferedPosition: _bufferedPosition,
    );
  }

  /// Extracts dominant and vibrant colors from song artwork asynchronously.
  Future<void> _extractDynamicColors(String imageUrl) async {
    try {
      final imageProvider = NetworkImage(imageUrl);
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 16,
      );

      Color baseColor = palette.darkVibrantColor?.color ??
          palette.darkMutedColor?.color ??
          palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          const Color(0xFFFF4E4E);

      if (HSLColor.fromColor(baseColor).saturation < 0.15) {
        final withChroma = palette.dominantColor?.color ??
            palette.vibrantColor?.color ??
            palette.lightVibrantColor?.color;
        if (withChroma != null &&
            HSLColor.fromColor(withChroma).saturation >= 0.15) {
          baseColor = withChroma;
        }
      }

      final hsl = HSLColor.fromColor(baseColor);

      final accentLightness =
          hsl.lightness < 0.45 ? 0.54 : hsl.lightness.clamp(0.48, 0.68);
      final accentSaturation =
          hsl.saturation < 0.45 ? 0.75 : hsl.saturation.clamp(0.60, 0.95);
      final vibrantAccent = hsl
          .withLightness(accentLightness)
          .withSaturation(accentSaturation)
          .toColor();

      final gradientBase = hsl
          .withLightness(hsl.lightness.clamp(0.12, 0.22))
          .withSaturation(hsl.saturation.clamp(0.45, 0.85))
          .toColor();

      _dynamicAccentColor = vibrantAccent;
      _dynamicGradient = <Color>[
        gradientBase.withValues(alpha: 0.90),
        const Color(0xFF0F0F13),
      ];
      notifyListeners();
    } catch (_) {}
  }

  /// Downloads track for offline playback.
  Future<bool> downloadSong(SongModel song) {
    _initOfflineServiceCallbacks();
    return offlineService.downloadSong(song, _extractor);
  }

  /// Removes offline download for track.
  Future<bool> removeDownload(String songId) =>
      offlineService.removeDownload(songId);

  /// Whether a song is saved for offline listening.
  bool isSongDownloaded(String songId) => offlineService.isDownloaded(songId);

  /// Whether a song is actively downloading.
  bool isSongDownloading(String songId) => offlineService.isDownloading(songId);

  /// Active download progress (0.0 to 1.0).
  double? getSongDownloadProgress(String songId) =>
      offlineService.getDownloadProgress(songId);

  /// All downloaded songs.
  List<SongModel> get downloadedSongs => offlineService.downloadedSongs;

  /// List of all songs currently actively downloading.
  List<SongModel> get activeDownloadSongs => offlineService.activeDownloadSongs;

  /// Cancels an in-progress download for [songId].
  void cancelDownload(String songId) => offlineService.cancelDownload(songId);

  /// Clears all downloaded audio files from device storage.
  Future<void> clearAllDownloads() => offlineService.clearAllDownloads();

  /// Custom user playlists list.
  List<PlaylistModel> get playlists => playlistService.playlists;

  /// Creates a new user playlist with [name].
  Future<PlaylistModel> createPlaylist(String name) =>
      playlistService.createPlaylist(name);

  /// Renames an existing playlist.
  Future<bool> renamePlaylist(String id, String newName) =>
      playlistService.renamePlaylist(id, newName);

  /// Deletes a playlist by its [id].
  Future<bool> deletePlaylist(String id) => playlistService.deletePlaylist(id);

  /// Adds a song to a playlist.
  Future<bool> addSongToPlaylist(String playlistId, SongModel song) =>
      playlistService.addSongToPlaylist(playlistId, song);

  /// Removes a song from a playlist.
  Future<bool> removeSongFromPlaylist(String playlistId, String songId) =>
      playlistService.removeSongFromPlaylist(playlistId, songId);

  /// Plays a full custom playlist starting from [startIndex], with optional shuffle mode.
  void playPlaylist(PlaylistModel playlist, {int startIndex = 0, bool shuffle = false}) {
    if (playlist.songs.isEmpty) return;
    _isPlaylistQueue = true;
    if (shuffle) {
      final shuffled = List<SongModel>.from(playlist.songs)..shuffle();
      _isShuffle = true;
      playSong(shuffled.first, newQueue: shuffled, isPlaylistQueue: true);
    } else {
      _isShuffle = false;
      final targetIndex = startIndex.clamp(0, playlist.songs.length - 1);
      playSong(playlist.songs[targetIndex], newQueue: playlist.songs, isPlaylistQueue: true);
    }
  }

  /// Loads persisted liked songs from disk into memory.
  Future<void> _loadLikedSongs() async {
    final file = _likedSongsFile;
    if (file == null || !await file.exists()) return;

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        _likedSongs.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final song = SongModel.fromMap(item);
            song.isLiked = true;
            _likedSongs.add(song);
          }
        }
      }
    } catch (e) {
      debugPrint('[MusicPlayerController] Error loading liked songs: $e');
    }
  }

  /// Persists liked songs list to disk atomically.
  Future<void> _persistLikedSongs() async {
    final file = _likedSongsFile;
    if (file == null) return;
    final list = _likedSongs.map((SongModel s) => s.toMap()).toList();
    await _writeJsonAtomically(file, list);
  }

  /// Loads persisted playback history from disk into memory.
  Future<void> _loadHistory() async {
    final file = _historyFile;
    if (file == null || !await file.exists()) return;

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        _history.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final song = SongModel.fromMap(item);
            song.isLiked = isSongLiked(song.id);
            _history.add(song);
          }
        }
      }
    } catch (e) {
      debugPrint('[MusicPlayerController] Error loading history: $e');
    }
  }

  /// Persists playback history list to disk atomically.
  Future<void> _persistHistory() async {
    final file = _historyFile;
    if (file == null) return;
    final list = _history.take(150).map((SongModel s) => s.toMap()).toList();
    await _writeJsonAtomically(file, list);
  }

  /// Loads persisted behavior analytics from disk.
  Future<void> _loadBehavior() async {
    final file = _behaviorFile;
    if (file == null || !await file.exists()) return;

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        behaviorTracker.loadFromMap(decoded);
      }
    } catch (e) {
      debugPrint('[MusicPlayerController] Error loading behavior: $e');
    }
  }

  /// Debounces saving behavioral analytics to disk to avoid excessive disk I/O.
  void _queuePersistBehavior() {
    _behaviorDebounceTimer?.cancel();
    _behaviorDebounceTimer = Timer(const Duration(seconds: 2), () {
      final file = _behaviorFile;
      if (file != null) {
        unawaited(_writeJsonAtomically(file, behaviorTracker.toMap()));
      }
    });
  }

  /// Loads persisted application settings from disk.
  Future<void> _loadSettings() async {
    final file = _settingsFile;
    if (file == null || !await file.exists()) return;

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final modeName = decoded['themeMode'] as String?;
        if (modeName != null) {
          _themeMode = ThemeMode.values.firstWhere(
            (ThemeMode m) => m.name == modeName,
            orElse: () => ThemeMode.system,
          );
        }
        final autoplay = decoded['isAutoplayEnabled'] as bool?;
        if (autoplay != null) {
          _isAutoplayEnabled = autoplay;
        }
      }
    } catch (e) {
      debugPrint('[MusicPlayerController] Error loading settings: $e');
    }
  }

  /// Persists application settings to disk atomically.
  Future<void> _persistSettings() async {
    final file = _settingsFile;
    if (file == null) return;
    final data = <String, Object>{
      'themeMode': _themeMode.name,
      'isAutoplayEnabled': _isAutoplayEnabled,
    };
    await _writeJsonAtomically(file, data);
  }

  /// Writes JSON data atomically using a temporary file to prevent corruption on unexpected termination.
  Future<void> _writeJsonAtomically(File targetFile, Object data) async {
    try {
      final tempFile = File('${targetFile.path}.tmp');
      final content = jsonEncode(data);
      await tempFile.writeAsString(content, flush: true);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
    } catch (e) {
      debugPrint(
        '[MusicPlayerController] Atomic write error for ${targetFile.path}: $e',
      );
    }
  }

  @override
  void dispose() {
    _behaviorDebounceTimer?.cancel();
    final bFile = _behaviorFile;
    if (bFile != null) {
      _writeJsonAtomically(bFile, behaviorTracker.toMap());
    }
    _offlineService?.removeListener(notifyListeners);
    _playlistService?.removeListener(notifyListeners);
    _playerSubscription?.cancel();
    _player.dispose();
    _extractor.close();
    positionNotifier.dispose();
    bufferedPositionNotifier.dispose();
    super.dispose();
  }
}
