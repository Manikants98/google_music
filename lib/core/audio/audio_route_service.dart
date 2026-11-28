// ignore_for_file: experimental_member_use

import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Categories of audio output hardware.
enum AudioRouteType {
  /// Wireless Bluetooth speakers, earphones, or TWS.
  bluetooth,

  /// Physical 3.5mm or Type-C / Lightning wired headphones.
  wired,

  /// Apple AirPlay wireless audio receiver.
  airPlay,

  /// Digital USB audio output or DAC.
  usb,

  /// Onboard device speakers (Phone, Mac, or Tablet).
  speaker,

  /// Other hardware outputs (HDMI, Line-out, etc.).
  other,
}

/// Represents information about an audio output destination.
class AudioRouteInfo {
  /// Unique identifier of the hardware port.
  final String id;

  /// Human-readable name of the speaker, headphones, or device.
  final String name;

  /// Classification of the route.
  final AudioRouteType type;

  /// Visual icon representing this route.
  final IconData icon;

  /// Whether this is the default onboard device speaker.
  final bool isDefaultSpeaker;

  /// Creates audio route info.
  const AudioRouteInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.isDefaultSpeaker = false,
  });

  /// Default fallback route when no external devices are connected.
  static const AudioRouteInfo defaultSpeaker = AudioRouteInfo(
    id: 'built_in_speaker',
    name: 'Device Speaker',
    type: AudioRouteType.speaker,
    icon: Icons.speaker_rounded,
    isDefaultSpeaker: true,
  );
}

/// Service that monitors the active audio output route (Bluetooth speaker, wired headphones, speaker).
class AudioRouteService {
  static final AudioRouteService instance = AudioRouteService._internal();

  AudioRouteService._internal();

  /// Reactive notifier holding the currently active audio route.
  final ValueNotifier<AudioRouteInfo> currentRouteNotifier =
      ValueNotifier<AudioRouteInfo>(AudioRouteInfo.defaultSpeaker);

  /// Reactive notifier holding all detected output hardware.
  final ValueNotifier<List<AudioRouteInfo>> allOutputDevicesNotifier =
      ValueNotifier<List<AudioRouteInfo>>(<AudioRouteInfo>[
        AudioRouteInfo.defaultSpeaker,
      ]);

  StreamSubscription<Set<AudioDevice>>? _devicesSubscription;
  StreamSubscription<AudioDevicesChangedEvent>? _eventSubscription;
  bool _initialized = false;

  /// Initializes audio route monitoring with the system audio session.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final session = await AudioSession.instance;
      final initialDevices = await session.getDevices();
      _handleDevicesUpdate(initialDevices);

      _devicesSubscription = session.devicesStream.listen(
        _handleDevicesUpdate,
        onError: (dynamic _) {},
      );

      _eventSubscription = session.devicesChangedEventStream.listen(
        (_) async {
          final refreshed = await session.getDevices();
          _handleDevicesUpdate(refreshed);
        },
        onError: (dynamic _) {},
      );
    } catch (_) {
      // Graceful fallback for environments where route inspection is restricted.
    }
  }

  /// Cleans raw device names reported by the OS / ALSA driver.
  /// E.g. strips redundant driver prefixes like "USB-Audio - " or "USB - ".
  static String cleanDeviceName(
    String? rawName, {
    String defaultFallback = 'Audio Device',
  }) {
    if (rawName == null) return defaultFallback;
    var name = rawName.trim();
    if (name.isEmpty) return defaultFallback;

    name = name.replaceFirst(
      RegExp(r'^(USB-Audio|USB\s*Audio|USB)\s*-\s*', caseSensitive: false),
      '',
    ).trim();

    return name.isEmpty ? defaultFallback : name;
  }

  /// Evaluates and selects the primary active output device based on OS routing priority.
  static AudioRouteInfo resolveActiveRoute(Set<AudioDevice> devices) {
    final outputs = devices.where((d) => d.isOutput).toList();
    if (outputs.isEmpty) {
      return AudioRouteInfo.defaultSpeaker;
    }

    // 1. High priority: Bluetooth (A2DP, LE, SCO)
    for (final d in outputs) {
      if (d.type == AudioDeviceType.bluetoothA2dp ||
          d.type == AudioDeviceType.bluetoothLe ||
          d.type == AudioDeviceType.bluetoothSco) {
        return AudioRouteInfo(
          id: d.id,
          name: cleanDeviceName(d.name, defaultFallback: 'Bluetooth Speaker'),
          type: AudioRouteType.bluetooth,
          icon: Icons.bluetooth_audio_rounded,
        );
      }
    }

    // 2. High priority: AirPlay
    for (final d in outputs) {
      if (d.type == AudioDeviceType.airPlay) {
        return AudioRouteInfo(
          id: d.id,
          name: cleanDeviceName(d.name, defaultFallback: 'AirPlay Speaker'),
          type: AudioRouteType.airPlay,
          icon: Icons.airplay_rounded,
        );
      }
    }

    // 3. Wired Headphones / Headset
    for (final d in outputs) {
      if (d.type == AudioDeviceType.wiredHeadphones ||
          d.type == AudioDeviceType.wiredHeadset) {
        return AudioRouteInfo(
          id: d.id,
          name: cleanDeviceName(d.name, defaultFallback: 'Wired Headphones'),
          type: AudioRouteType.wired,
          icon: Icons.headphones_rounded,
        );
      }
    }

    // 4. USB Audio / DAC
    for (final d in outputs) {
      if (d.type == AudioDeviceType.usbAudio) {
        return AudioRouteInfo(
          id: d.id,
          name: cleanDeviceName(d.name, defaultFallback: 'USB Audio Device'),
          type: AudioRouteType.usb,
          icon: Icons.usb_rounded,
        );
      }
    }

    // 5. Built-in Speaker
    for (final d in outputs) {
      if (d.type == AudioDeviceType.builtInSpeaker ||
          d.type == AudioDeviceType.builtInEarpiece) {
        final platformLabel = switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'iPhone Speaker',
          TargetPlatform.macOS => 'Mac Speaker',
          TargetPlatform.android => 'Phone Speaker',
          TargetPlatform.windows => 'PC Speaker',
          _ => 'Device Speaker',
        };

        return AudioRouteInfo(
          id: d.id,
          name: cleanDeviceName(d.name, defaultFallback: platformLabel),
          type: AudioRouteType.speaker,
          icon: Icons.speaker_rounded,
          isDefaultSpeaker: true,
        );
      }
    }

    // 6. Generic output fallback
    final first = outputs.first;
    return AudioRouteInfo(
      id: first.id,
      name: cleanDeviceName(first.name, defaultFallback: 'Audio Output'),
      type: AudioRouteType.other,
      icon: Icons.volume_up_rounded,
    );
  }

  void _handleDevicesUpdate(Set<AudioDevice> devices) {
    final active = resolveActiveRoute(devices);
    currentRouteNotifier.value = active;

    final outputs = devices.where((d) => d.isOutput).map((d) {
      final isBt = d.type == AudioDeviceType.bluetoothA2dp ||
          d.type == AudioDeviceType.bluetoothLe ||
          d.type == AudioDeviceType.bluetoothSco;
      final isWired = d.type == AudioDeviceType.wiredHeadphones ||
          d.type == AudioDeviceType.wiredHeadset;
      final isAirPlay = d.type == AudioDeviceType.airPlay;
      final isUsb = d.type == AudioDeviceType.usbAudio;
      final isSpk = d.type == AudioDeviceType.builtInSpeaker;

      final kind = isBt
          ? AudioRouteType.bluetooth
          : isWired
              ? AudioRouteType.wired
              : isAirPlay
                  ? AudioRouteType.airPlay
                  : isUsb
                      ? AudioRouteType.usb
                      : isSpk
                          ? AudioRouteType.speaker
                          : AudioRouteType.other;

      final icon = isBt
          ? Icons.bluetooth_audio_rounded
          : isWired
              ? Icons.headphones_rounded
              : isAirPlay
                  ? Icons.airplay_rounded
                  : isUsb
                      ? Icons.usb_rounded
                      : isSpk
                          ? Icons.speaker_rounded
                          : Icons.volume_up_rounded;

      return AudioRouteInfo(
        id: d.id,
        name: cleanDeviceName(d.name, defaultFallback: 'Audio Device'),
        type: kind,
        icon: icon,
        isDefaultSpeaker: isSpk,
      );
    }).toList();

    if (outputs.isEmpty) {
      allOutputDevicesNotifier.value = <AudioRouteInfo>[
        AudioRouteInfo.defaultSpeaker,
      ];
    } else {
      allOutputDevicesNotifier.value = outputs;
    }
  }

  /// Cancels active subscriptions.
  void dispose() {
    _devicesSubscription?.cancel();
    _eventSubscription?.cancel();
  }
}
