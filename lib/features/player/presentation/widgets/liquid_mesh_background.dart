import 'dart:math' as math;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

/// Apple Music inspired fluid liquid mesh animated background.
///
/// Features:
/// - 4 multi-colored fluid organic color orbs floating on non-repeating Lissajous curves.
/// - Smooth cross-fade color lerping between track transitions.
/// - Dynamic tempo adaptation (fluid motion during playback, gentle ambient drift when paused).
/// - Heavy frosted Gaussian blur and contrast-preserving vignette overlay.
class LiquidMeshBackground extends StatefulWidget {
  /// Dominant dynamic accent color extracted from album artwork.
  final Color primaryColor;

  /// Optional palette colors extracted from album artwork.
  final List<Color> paletteColors;

  /// Whether audio is actively playing (adapts motion flow speed).
  final bool isPlaying;

  /// Whether app theme is currently in dark mode.
  final bool isDark;

  /// Frosted glass blur intensity. Defaults to 75.0.
  final double blurSigma;

  /// Optional child content rendered above the liquid canvas.
  final Widget? child;

  /// Creates a liquid mesh background canvas.
  const LiquidMeshBackground({
    super.key,
    required this.primaryColor,
    this.paletteColors = const <Color>[],
    this.isPlaying = true,
    this.isDark = true,
    this.blurSigma = 75.0,
    this.child,
  });

  @override
  State<LiquidMeshBackground> createState() => _LiquidMeshBackgroundState();
}

class _LiquidMeshBackgroundState extends State<LiquidMeshBackground>
    with TickerProviderStateMixin {
  late final AnimationController _flowController;
  late final AnimationController _colorTransitionController;

  late List<Color> _sourceColors;
  late List<Color> _targetColors;

  double _simulatedTime = 0.0;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();

    _targetColors = _generateHarmonicPalette(
      widget.primaryColor,
      widget.paletteColors,
      widget.isDark,
    );
    _sourceColors = List<Color>.from(_targetColors);

    // Continuous motion ticker
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(_onFlowTick);
    _flowController.repeat();

    // Smooth color cross-fade animation controller
    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  void _onFlowTick() {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastTick).inMicroseconds / 1000000.0;
    _lastTick = now;

    // Fluid speed when playing, relaxed drift when paused
    final speed = widget.isPlaying ? 1.0 : 0.35;
    _simulatedTime += elapsedMs * speed;
  }

  @override
  void didUpdateWidget(covariant LiquidMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    final colorsChanged = oldWidget.primaryColor != widget.primaryColor ||
        oldWidget.isDark != widget.isDark ||
        oldWidget.paletteColors != widget.paletteColors;

    if (colorsChanged) {
      // Snapshot current interpolated colors as new source
      _sourceColors = _getCurrentInterpolatedColors();
      _targetColors = _generateHarmonicPalette(
        widget.primaryColor,
        widget.paletteColors,
        widget.isDark,
      );

      _colorTransitionController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _flowController.removeListener(_onFlowTick);
    _flowController.dispose();
    _colorTransitionController.dispose();
    super.dispose();
  }

  /// Synthesizes 4 rich, expressive harmonious orb colors from active artwork tones.
  List<Color> _generateHarmonicPalette(
    Color primary,
    List<Color> palette,
    bool isDark,
  ) {
    final hsl = HSLColor.fromColor(primary);

    Color c1;
    Color c2;
    Color c3;
    Color c4;

    if (palette.length >= 3) {
      c1 = palette[0];
      c2 = palette[1];
      c3 = palette[2];
      c4 = palette.length >= 4 ? palette[3] : primary;
    } else {
      // Algorithmic color harmony generation via hue shifting
      c1 = primary;

      // Analogous shift +38 degrees
      final hue2 = (hsl.hue + 38.0) % 360.0;
      c2 = hsl.withHue(hue2).withLightness(isDark ? 0.48 : 0.62).toColor();

      // Complementary/triadic shift -42 degrees
      final hue3 = (hsl.hue - 42.0 + 360.0) % 360.0;
      c3 = hsl.withHue(hue3).withLightness(isDark ? 0.38 : 0.55).toColor();

      // Atmospheric deep accent
      final hue4 = (hsl.hue + 120.0) % 360.0;
      c4 = hsl
          .withHue(hue4)
          .withSaturation((hsl.saturation * 0.8).clamp(0.4, 0.9))
          .withLightness(isDark ? 0.30 : 0.65)
          .toColor();
    }

    return <Color>[c1, c2, c3, c4];
  }

  List<Color> _getCurrentInterpolatedColors() {
    final t = CurvedAnimation(
      parent: _colorTransitionController,
      curve: Curves.easeInOutCubic,
    ).value;

    return List<Color>.generate(4, (index) {
      return Color.lerp(_sourceColors[index], _targetColors[index], t) ??
          _targetColors[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color canvasBaseColor = widget.isDark
        ? const Color(0xFF0C0D12)
        : const Color(0xFFF2F4F8);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Base Dark Slate Canvas
          ColoredBox(color: canvasBaseColor),

          // 2. Multi-Orb Fluid Liquid Canvas (Animated 60/120fps)
          AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _flowController,
              _colorTransitionController,
            ]),
            builder: (BuildContext context, _) {
              return CustomPaint(
                painter: _LiquidMeshPainter(
                  colors: _getCurrentInterpolatedColors(),
                  time: _simulatedTime,
                  isDark: widget.isDark,
                  isPlaying: widget.isPlaying,
                ),
              );
            },
          ),

          // 3. Heavy Gaussian Frosted Blur Layer (Melts gradients into liquid mesh)
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
            ),
            child: const SizedBox.expand(),
          ),

          // 4. Contrast Protection Vignette
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.isDark
                    ? <Color>[
                        Colors.black.withValues(alpha: 0.38),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.65),
                      ]
                    : <Color>[
                        Colors.white.withValues(alpha: 0.40),
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.25),
                        Colors.white.withValues(alpha: 0.55),
                      ],
                stops: const <double>[0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),

          // 5. Optional Child Foreground
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// Custom painter rendering organic floating radial orbs on sinusoidal Lissajous paths.
class _LiquidMeshPainter extends CustomPainter {
  final List<Color> colors;
  final double time;
  final bool isDark;
  final bool isPlaying;

  const _LiquidMeshPainter({
    required this.colors,
    required this.time,
    required this.isDark,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final alphaCore = isDark ? 0.75 : 0.60;
    final alphaMid = isDark ? 0.38 : 0.28;

    // --- ORB 1: Primary Accent (Top-Left / Center Drift) ---
    final x1 = w * (0.32 + 0.22 * math.sin(time * 0.42 + 0.4));
    final y1 = h * (0.24 + 0.16 * math.cos(time * 0.36 + 1.1));
    final r1 = w * (0.65 + 0.10 * math.sin(time * 0.30));
    _drawFluidOrb(canvas, Offset(x1, y1), r1, colors[0], alphaCore, alphaMid);

    // --- ORB 2: Secondary Tone (Top-Right / Mid Drift) ---
    final x2 = w * (0.75 + 0.20 * math.cos(time * 0.33 + 2.3));
    final y2 = h * (0.38 + 0.20 * math.sin(time * 0.40 + 0.8));
    final r2 = w * (0.70 + 0.08 * math.cos(time * 0.26));
    _drawFluidOrb(canvas, Offset(x2, y2), r2, colors[1], alphaCore, alphaMid);

    // --- ORB 3: Harmonic Shift (Bottom-Left / Mid Bloom) ---
    final x3 = w * (0.22 + 0.24 * math.sin(time * 0.31 + 4.1));
    final y3 = h * (0.68 + 0.18 * math.cos(time * 0.45 + 3.0));
    final r3 = w * (0.72 + 0.11 * math.sin(time * 0.35));
    _drawFluidOrb(canvas, Offset(x3, y3), r3, colors[2], alphaCore, alphaMid);

    // --- ORB 4: Accent Undertone (Bottom-Right / Deep Atmosphere) ---
    final x4 = w * (0.72 + 0.20 * math.cos(time * 0.38 + 1.6));
    final y4 = h * (0.76 + 0.16 * math.sin(time * 0.32 + 2.6));
    final r4 = w * (0.68 + 0.09 * math.cos(time * 0.38));
    _drawFluidOrb(canvas, Offset(x4, y4), r4, colors[3], alphaCore, alphaMid);
  }

  void _drawFluidOrb(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alphaCore,
    double alphaMid,
  ) {
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: <Color>[
        color.withValues(alpha: alphaCore),
        color.withValues(alpha: alphaMid),
        color.withValues(alpha: 0.0),
      ],
      stops: const <double>[0.0, 0.45, 1.0],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = isDark ? BlendMode.screen : BlendMode.multiply;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidMeshPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.colors != colors ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.isDark != isDark;
  }
}
