import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../audio/music_player_controller.dart';
import '../../features/player/presentation/now_playing_sheet.dart';

/// Platform channel bridge managing native Android download and playback notification tap routing.
class DownloadNotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.mkx.google_music/download_notification');

  static GlobalKey<NavigatorState>? _navKey;
  static StreamSubscription<bool>? _audioNotificationSub;

  /// Initializes method call handler and AudioService listener for notification tap navigation.
  static void initialize(GlobalKey<NavigatorState> key) {
    _navKey = key;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openNowPlaying') {
        openNowPlaying();
      }
    });

    _audioNotificationSub?.cancel();
    _audioNotificationSub = AudioService.notificationClicked.listen((clicked) {
      if (clicked) {
        openNowPlaying();
      }
    });

    unawaited(checkPendingRoute());
  }

  /// Checks if there was a pending route from cold launch.
  static Future<void> checkPendingRoute() async {
    try {
      final route = await _channel.invokeMethod<String>('getPendingRoute');
      if (route == 'now_playing') {
        openNowPlaying();
      }
    } catch (_) {}
  }

  /// Opens the Now Playing screen when the music notification is tapped.
  static void openNowPlaying() {
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      final navContext = _navKey?.currentContext;
      if (navContext != null && navContext.mounted) {
        try {
          final controller = navContext.read<MusicPlayerController>();
          if (controller.currentSong != null) {
            NowPlayingSheet.show(navContext);
          }
        } catch (_) {}
      }
    });
  }

  /// Displays or updates a dedicated native download notification with progress bar and percentage.
  static Future<void> showProgress({
    required String id,
    required String title,
    required int percent,
  }) async {
    try {
      await _channel.invokeMethod<void>('showProgress', <String, Object>{
        'id': id,
        'title': title,
        'percent': percent,
      });
    } catch (_) {}
  }

  /// Displays completed download state in the separate native notification.
  static Future<void> showComplete({
    required String id,
    required String title,
  }) async {
    try {
      await _channel.invokeMethod<void>('showComplete', <String, Object>{
        'id': id,
        'title': title,
      });
    } catch (_) {}
  }

  /// Dismisses a specific download notification, or all active notifications if [id] is omitted.
  static Future<void> cancel({String? id}) async {
    try {
      final args = <String, Object>{};
      if (id != null) {
        args['id'] = id;
      }
      await _channel.invokeMethod<void>('cancel', args);
    } catch (_) {}
  }

  /// Dismisses all active download notifications.
  static Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } catch (_) {}
  }
}
