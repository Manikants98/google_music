import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:just_audio_platform_interface/method_channel_just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Platform implementation that tracks active just_audio player IDs on disk
/// so any orphaned players running on native iOS/Android can be reliably paused
/// and disposed upon Flutter hot restarts or session initialization.
class TrackedJustAudioPlatform extends MethodChannelJustAudio {
  static final Set<String> _activePlayerIds = <String>{};
  static File? _cacheFile;
  static bool _installed = false;

  /// Installs tracking platform and immediately stops any previous players from dead isolates.
  static Future<void> install() async {
    if (!_installed) {
      JustAudioPlatform.instance = TrackedJustAudioPlatform();
      _installed = true;
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      _cacheFile = File('${docDir.path}/active_player_ids.json');
      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
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

  /// Commands all previously registered native players on iOS/Android to pause and stop.
  static Future<void> stopAllPreviousPlayers() async {
    try {
      const nativeChannel =
          MethodChannel('com.mkx.google_music/download_notification');
      await nativeChannel.invokeMethod<void>('stopAllAudio');
    } catch (_) {}

    final idsToStop = Set<String>.from(_activePlayerIds);
    for (final id in idsToStop) {
      try {
        final channel = MethodChannel('com.ryanheise.just_audio.methods.$id');
        await channel.invokeMethod<void>('pause');
        await channel.invokeMethod<void>('stop');
      } catch (_) {}
      try {
        const mainChannel = MethodChannel('com.ryanheise.just_audio.methods');
        await mainChannel.invokeMethod<void>('disposePlayer', <String, Object>{'id': id});
      } catch (_) {}
    }
    _activePlayerIds.clear();
    await _save();
  }

  static Future<void> _save() async {
    try {
      final file = _cacheFile;
      if (file != null) {
        await file.writeAsString(jsonEncode(_activePlayerIds.toList()), flush: true);
      }
    } catch (_) {}
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    _activePlayerIds.add(request.id);
    unawaited(_save());
    return super.init(request);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    _activePlayerIds.remove(request.id);
    unawaited(_save());
    return super.disposePlayer(request);
  }
}
