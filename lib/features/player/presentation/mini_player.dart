import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../models/playback_state.dart';
import 'now_playing_sheet.dart';

/// Floating expressive pill mini player docked above bottom navigation.
/// Supports smooth interactive drag gestures:
/// - Swipe Left: Skip to next track
/// - Swipe Right: Skip to previous track
/// - Swipe Up / Tap: Expand Now Playing sheet
class MiniPlayerPill extends StatefulWidget {
  /// Creates mini player.
  const MiniPlayerPill({super.key});

  @override
  State<MiniPlayerPill> createState() => _MiniPlayerPillState();
}

class _MiniPlayerPillState extends State<MiniPlayerPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideAnimController;
  final ValueNotifier<double> _dragNotifier = ValueNotifier<double>(0.0);
  double _rawDragY = 0.0;

  @override
  void initState() {
    super.initState();
    _slideAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _slideAnimController.dispose();
    _dragNotifier.dispose();
    super.dispose();
  }

  /// Expands full modal now playing sheet.
  void _openNowPlaying(BuildContext context) {
    NowPlayingSheet.show(context);
  }

  /// Smoothly animates drag displacement back to resting 0.0 position.
  void _animateReset() {
    if (_slideAnimController.isAnimating) {
      _slideAnimController.stop();
    }
    final startX = _dragNotifier.value;
    final animation = Tween<double>(begin: startX, end: 0.0).animate(
      CurvedAnimation(
        parent: _slideAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    void listener() {
      _dragNotifier.value = animation.value;
    }

    animation.addListener(listener);
    _slideAnimController.forward(from: 0.0).then((_) {
      animation.removeListener(listener);
      _dragNotifier.value = 0.0;
    });
  }

  /// Performs fluid slide-out and slide-in transition upon track skip.
  Future<void> _animateSlideAndChange(
    MusicPlayerController controller, {
    required bool isNext,
  }) async {
    if (_slideAnimController.isAnimating) {
      _slideAnimController.stop();
    }
    final currentX = _dragNotifier.value;
    final targetExitX = isNext ? -120.0 : 120.0;
    final enterStartX = isNext ? 120.0 : -120.0;

    /// 1. Smoothly finish sliding out in swipe direction
    final exitAnimation =
        Tween<double>(begin: currentX, end: targetExitX).animate(
      CurvedAnimation(
        parent: _slideAnimController,
        curve: Curves.easeOutQuad,
      ),
    );
    void exitListener() {
      _dragNotifier.value = exitAnimation.value;
    }

    exitAnimation.addListener(exitListener);
    await _slideAnimController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 90),
    );
    exitAnimation.removeListener(exitListener);

    /// 2. Trigger skip
    if (isNext) {
      controller.playNext();
    } else {
      controller.playPrevious();
    }

    /// 3. Reposition to opposite side and slide in
    _dragNotifier.value = enterStartX;
    final enterAnimation =
        Tween<double>(begin: enterStartX, end: 0.0).animate(
      CurvedAnimation(
        parent: _slideAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    void enterListener() {
      _dragNotifier.value = enterAnimation.value;
    }

    enterAnimation.addListener(enterListener);
    await _slideAnimController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 180),
    );
    enterAnimation.removeListener(enterListener);
    _dragNotifier.value = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicPlayerController>();
    final song = controller.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = controller.dynamicAccentColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openNowPlaying(context),
        onHorizontalDragStart: (DragStartDetails details) {
          if (_slideAnimController.isAnimating) {
            _slideAnimController.stop();
          }
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          /// 1:1 responsive tracking with subtle damping at limits
          double current = _dragNotifier.value + details.delta.dx;
          if (current > 70.0) {
            current = 70.0 + (current - 70.0) * 0.25;
          } else if (current < -70.0) {
            current = -70.0 + (current + 70.0) * 0.25;
          }
          _dragNotifier.value = current.clamp(-90.0, 90.0);
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          final velocity = details.primaryVelocity ?? 0.0;
          final currentX = _dragNotifier.value;

          if (currentX < -32.0 || velocity < -350.0) {
            HapticFeedback.mediumImpact();
            _animateSlideAndChange(controller, isNext: true);
          } else if (currentX > 32.0 || velocity > 350.0) {
            HapticFeedback.mediumImpact();
            _animateSlideAndChange(controller, isNext: false);
          } else {
            _animateReset();
          }
        },
        onVerticalDragUpdate: (DragUpdateDetails details) {
          _rawDragY += details.delta.dy;
        },
        onVerticalDragEnd: (DragEndDetails details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (_rawDragY < -24.0 || velocity < -200.0) {
            HapticFeedback.lightImpact();
            _openNowPlaying(context);
          }
          _rawDragY = 0.0;
        },
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.35 : 0.08,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _dragNotifier,
                          builder: (context, dragX, child) {
                            final double opacity =
                                (1.0 - (dragX.abs() / 130.0)).clamp(0.25, 1.0);
                            return Transform.translate(
                              offset: Offset(dragX, 0),
                              child: Opacity(
                                opacity: opacity,
                                child: child,
                              ),
                            );
                          },
                          child: Row(
                            children: <Widget>[
                              M3EAlbumArt(
                                imageUrl: song.thumbnailUrl,
                                size: 42,
                                radius: 4,
                                elevation: 0,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    M3EMarqueeText(
                                      text: song.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: controller.status == PlayerStatus.loading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: M3EProgressIndicator.circular(
                                  strokeWidth: 2.5,
                                  trackStrokeWidth: 2.5,
                                  color: accent,
                                  trackColor: accent.withValues(alpha: 0.22),
                                ),
                              )
                            : Icon(
                                controller.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: colorScheme.onSurface,
                                size: 28,
                              ),
                        onPressed: controller.togglePlayPause,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 24),
                        onPressed: controller.playNext,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: controller.positionNotifier,
                    builder: (context, pos, child) {
                      final dur = controller.duration;
                      final progress = dur.inMilliseconds > 0
                          ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
