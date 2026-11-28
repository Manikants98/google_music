import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:just_audio_platform_interface/method_channel_just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Platform implementation that tracks active just_audio player IDs on disk
/// and reliably disposes all orphaned native iOS/Android audio players upon
/// Flutter hot restarts or app re-initialization.
class TrackedJustAudioPlatform extends MethodChannelJustAudio {
  static final Set<String> _activePlayerIds = <String>{};
  static File? _cacheFile;
  static bool _installed = false;

  /// Helper to get or lazily initialize the cache file reference.
  static Future<File?> _getCacheFile() async {
    if (_cacheFile != null) return _cacheFile;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _cacheFile = File('${docDir.path}/active_player_ids.json');
      return _cacheFile;
    } catch (_) {
      return null;
    }
  }

  /// Installs tracking platform and immediately stops any previous players from dead isolates.
  static Future<void> install() async {
    if (!_installed) {
      JustAudioPlatform.instance = TrackedJustAudioPlatform();
      _installed = true;
    }

    // 1. Instantly kill all native players on iOS & Android via just_audio's main channel
    try {
      const mainChannel = MethodChannel('com.ryanheise.just_audio.methods');
      await mainChannel.invokeMethod<dynamic>('disposeAllPlayers');
    } catch (e) {
      debugPrint('[TrackedJustAudioPlatform] disposeAllPlayers error: $e');
    }

    // 2. Immediately deactivate the audio session so any remaining buffers fall silent
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}

    // 3. Command native AppDelegate / MainActivity to halt all audio
    try {
      const nativeChannel =
          MethodChannel('com.mkx.google_music/download_notification');
      await nativeChannel.invokeMethod<dynamic>('stopAllAudio');
    } catch (_) {}

    // 4. Load persisted IDs from disk to explicitly pause each one individually
    try {
      final file = await _getCacheFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final dynamic decoded = jsonDecode(content);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is String && item.isNotEmpty) {
                _activePlayerIds.add(item);
              }
            }
          }
        }
      }
    } catch (_) {}

    await stopAllPreviousPlayers();
  }

  /// Commands all previously registered native players on iOS/Android to mute, pause, and dispose.
  static Future<void> stopAllPreviousPlayers() async {
    // 1. Direct channel disposal
    try {
      const mainChannel = MethodChannel('com.ryanheise.just_audio.methods');
      await mainChannel.invokeMethod<dynamic>('disposeAllPlayers');
    } catch (_) {}

    // 2. Individual player mute & pause
    final idsToStop = Set<String>.from(_activePlayerIds);
    for (final id in idsToStop) {
      try {
        final channel = MethodChannel('com.ryanheise.just_audio.methods.$id');
        await channel.invokeMethod<dynamic>(
          'setVolume',
          <String, dynamic>{'volume': 0.0},
        );
        await channel.invokeMethod<dynamic>('pause');
      } catch (_) {}
      try {
        const mainChannel = MethodChannel('com.ryanheise.just_audio.methods');
        await mainChannel.invokeMethod<dynamic>(
          'disposePlayer',
          <String, dynamic>{'id': id},
        );
      } catch (_) {}
    }
    _activePlayerIds.clear();
    await _save();

    // 3. Deactivate session
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final file = await _getCacheFile();
      if (file != null) {
        await file.writeAsString(
          jsonEncode(_activePlayerIds.toList()),
          flush: true,
        );
      }
    } catch (_) {}
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    _activePlayerIds.add(request.id);
    await _save();
    return super.init(request);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    _activePlayerIds.remove(request.id);
    await _save();
    return super.disposePlayer(request);
  }
}
