import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Signature Google Pixel expressive wavy soundwave progress slider.
class WavySlider extends StatefulWidget {
  /// Current playback position.
  final Duration position;

  /// Total duration of track.
  final Duration duration;

  /// Whether audio is actively playing.
  final bool isPlaying;

  /// Accent color of the active wave track.
  final Color activeColor;

  /// Background color of inactive track.
  final Color inactiveColor;

  /// Callback when user seeks to a new position.
  final ValueChanged<Duration> onSeek;

  /// Creates wavy slider.
  const WavySlider({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.activeColor,
    this.inactiveColor = const Color(0x33FFFFFF),
    required this.onSeek,
  });

  @override
  State<WavySlider> createState() => _WavySliderState();
}

class _WavySliderState extends State<WavySlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WavySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isPlaying && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Formats duration to mm:ss format.
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final currentMs = _dragValue != null
        ? (_dragValue! * (totalMs > 0 ? totalMs : 1)).round()
        : widget.position.inMilliseconds;

    final progress = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                if (width <= 0) return;
                M3EHaptics.trigger(M3EHapticFeedback.light);
                final val = (details.localPosition.dx / width).clamp(0.0, 1.0);
                setState(() {
                  _dragValue = val;
                });
              },
              onHorizontalDragUpdate: (details) {
                if (width <= 0) return;
                final val = (details.localPosition.dx / width).clamp(0.0, 1.0);
                setState(() {
                  _dragValue = val;
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragValue != null && totalMs > 0) {
                  final target = Duration(
                    milliseconds: (_dragValue! * totalMs).round(),
                  );
                  widget.onSeek(target);
                }
                setState(() {
                  _dragValue = null;
                });
              },
              onTapDown: (details) {
                if (width <= 0) return;
                M3EHaptics.trigger(M3EHapticFeedback.light);
                final val = (details.localPosition.dx / width).clamp(0.0, 1.0);
                if (totalMs > 0) {
                  final target =
                      Duration(milliseconds: (val * totalMs).round());
                  widget.onSeek(target);
                }
              },
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(double.infinity, 36),
                    painter: _WavyTrackPainter(
                      progress: progress,
                      phase: _animController.value * 2 * math.pi,
                      isPlaying: widget.isPlaying,
                      activeColor: widget.activeColor,
                      inactiveColor: widget.inactiveColor,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _formatDuration(Duration(milliseconds: currentMs)),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    _formatDuration(widget.duration),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for the animated wave line and inactive track.
class _WavyTrackPainter extends CustomPainter {
  final double progress;
  final double phase;
  final bool isPlaying;
  final Color activeColor;
  final Color inactiveColor;

  const _WavyTrackPainter({
    required this.progress,
    required this.phase,
    required this.isPlaying,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final activeWidth = size.width * progress;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (activeWidth < size.width) {
      canvas.drawLine(
        Offset(activeWidth + 8, centerY),
        Offset(size.width, centerY),
        inactivePaint,
      );
    }

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (activeWidth > 0) {
      final path = Path();
      path.moveTo(0, centerY);

      final wavelength = 36.0;
      final amplitude = isPlaying ? 3.5 : 0.0;

      for (double x = 0; x <= activeWidth; x += 2.0) {
        final y = centerY + math.sin((x / wavelength) * 2 * math.pi + phase) * amplitude;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, activePaint);
    }

    final thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final thumbRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(activeWidth.clamp(6.0, size.width - 6.0), centerY),
        width: 12,
        height: 24,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(thumbRRect, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _WavyTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.activeColor != activeColor;
  }
}
