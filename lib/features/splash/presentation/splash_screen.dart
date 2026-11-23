import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated splash screen for Google Music displaying brand logo and audio waveform.
class GoogleMusicSplashScreen extends StatefulWidget {
  /// The target screen widget to navigate to after splash timeout.
  final Widget nextScreen;

  /// Creates a splash screen.
  const GoogleMusicSplashScreen({super.key, required this.nextScreen});

  @override
  State<GoogleMusicSplashScreen> createState() =>
      _GoogleMusicSplashScreenState();
}

class _GoogleMusicSplashScreenState extends State<GoogleMusicSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    /// Equalizer wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    /// Navigate to target screen after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF121316)
        : const Color(0xFFF8F9FA);
    final titleColor = isDark
        ? const Color(0xFFF1F3F4)
        : const Color(0xFF3C4043);
    final subtitleColor = isDark
        ? const Color(0xFF9AA0A6)
        : const Color(0xFF5F6368);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            /// Center Logo and App Title - locked to exact screen center
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(
                    'assets/images/google_music_logo.png',
                    width: 135,
                    height: 135,
                  ),
                  Text(
                    'Google Music',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
            ),

            /// Bottom Animated Equalizer and "Powered by MKX" - locked to bottom
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: <Widget>[
                    SizedBox(
                      height: 40,
                      child: _GoogleEqualizerWave(controller: _waveController),
                    ),
                    Text(
                      'Powered by MKX',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic Google-palette equalizer waveform displaying bouncing rhythmic bars.
class _GoogleEqualizerWave extends StatelessWidget {
  /// Driving animation controller.
  final AnimationController controller;

  /// Creates equalizer wave.
  const _GoogleEqualizerWave({required this.controller});

  static const List<Color> _barColors = <Color>[
    Color(0xFFA8C7FA),
    Color(0xFFEA4335),
    Color(0xFFFBBC05),
    Color(0xFF34A853),
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFF34A853),
    Color(0xFFFBBC05),
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFF34A853),
    Color(0xFFFBBC05),
    Color(0xFFA8C7FA),
  ];

  static const List<double> _baseHeights = <double>[
    8,
    16,
    22,
    12,
    18,
    28,
    14,
    34,
    24,
    16,
    26,
    18,
    10,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(_baseHeights.length, (index) {
              final phase = (controller.value * 2 * math.pi) + (index * 0.65);
              final waveFactor = 0.65 + 0.35 * math.sin(phase);
              final height = _baseHeights[index] * waveFactor;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: _barColors[index],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
