/// Playback mode representing loop behavior.
enum LoopMode {
  /// Play through queue without repeating.
  off,

  /// Loop current queue endlessly.
  all,

  /// Loop the currently active song track.
  one,
}

/// Operational state of the audio engine.
enum PlayerStatus {
  /// No track selected.
  idle,

  /// Extracting audio stream and buffering.
  loading,

  /// Active audio output.
  playing,

  /// Audio paused.
  paused,

  /// Playback error encountered.
  error,
}
