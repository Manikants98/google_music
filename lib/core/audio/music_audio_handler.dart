import 'package:audio_service/audio_service.dart';

/// Handler managing system notifications and lockscreen media transport controls.
class GoogleMusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  /// Callback for play transport action.
  Future<void> Function()? onPlay;

  /// Callback for pause transport action.
  Future<void> Function()? onPause;

  /// Callback for skip to next track action.
  Future<void> Function()? onSkipToNext;

  /// Callback for skip to previous track action.
  Future<void> Function()? onSkipToPrevious;

  /// Callback for seek transport action.
  Future<void> Function(Duration position)? onSeek;

  /// Callback for stop action.
  Future<void> Function()? onStop;

  /// Updates the current media metadata displayed in notification and lockscreen.
  void setTrackMetadata({
    required String id,
    required String title,
    required String artist,
    required String artUri,
    Duration? duration,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: 'Google Music',
        artUri: Uri.tryParse(artUri),
        duration: duration,
        playable: true,
      ),
    );
  }

  /// Updates the notification playback state (controls, seek position, state).
  void updateState({
    required bool isPlaying,
    required AudioProcessingState processingState,
    required Duration position,
    required Duration bufferedPosition,
    double speed = 1.0,
  }) {
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: speed,
        updateTime: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> play() async {
    if (onPlay != null) {
      await onPlay!();
    }
  }

  @override
  Future<void> pause() async {
    if (onPause != null) {
      await onPause!();
    }
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      await onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (onSeek != null) {
      await onSeek!(position);
    }
  }

  @override
  Future<void> stop() async {
    if (onStop != null) {
      await onStop!();
    }
    await super.stop();
  }
}
