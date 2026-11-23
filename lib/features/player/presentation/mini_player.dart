import 'package:flutter/material.dart';
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
  late final AnimationController _resetAnimController;
  late Animation<double> _dragAnimation;
  double _dragX = 0.0;
  double _dragY = 0.0;

  @override
  void initState() {
    super.initState();
    _resetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        setState(() {
          _dragX = _dragAnimation.value;
        });
      });
    _dragAnimation = const AlwaysStoppedAnimation<double>(0.0);
  }

  @override
  void dispose() {
    _resetAnimController.dispose();
    super.dispose();
  }

  /// Expands full modal now playing sheet.
  void _openNowPlaying(BuildContext context) {
    NowPlayingSheet.show(context);
  }

  /// Smoothly animates drag displacement back to resting position.
  void _animateReset() {
    _dragAnimation = Tween<double>(begin: _dragX, end: 0.0).animate(
      CurvedAnimation(
        parent: _resetAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _resetAnimController.forward(from: 0.0);
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

    final progress = controller.duration.inMilliseconds > 0
        ? (controller.position.inMilliseconds /
                  controller.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;

    final double contentOpacity =
        (1.0 - (_dragX.abs() / 140.0)).clamp(0.4, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openNowPlaying(context),
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (_resetAnimController.isAnimating) {
            _resetAnimController.stop();
          }
          setState(() {
            _dragX += details.delta.dx * 0.75;
            _dragX = _dragX.clamp(-75.0, 75.0);
          });
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (_dragX < -28 || velocity < -250) {
            HapticFeedback.mediumImpact();
            controller.playNext();
          } else if (_dragX > 28 || velocity > 250) {
            HapticFeedback.mediumImpact();
            controller.playPrevious();
          }
          _animateReset();
        },
        onVerticalDragUpdate: (DragUpdateDetails details) {
          _dragY += details.delta.dy;
        },
        onVerticalDragEnd: (DragEndDetails details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (_dragY < -24 || velocity < -180) {
            HapticFeedback.lightImpact();
            _openNowPlaying(context);
          }
          _dragY = 0.0;
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
                        child: Transform.translate(
                          offset: Offset(_dragX, 0),
                          child: Opacity(
                            opacity: contentOpacity,
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
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
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
