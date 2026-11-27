import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../core/widgets/wavy_slider.dart';
import '../../../models/playback_state.dart';
import 'queue_bottom_sheet.dart';
import 'sleep_timer_sheet.dart';

/// Full screen immersive Google Music player with responsive dynamic layout and wavy soundwave slider.
class NowPlayingSheet extends StatelessWidget {
  /// Tracks if the now playing modal is currently open.
  static bool _isOpen = false;

  /// Whether the NowPlayingSheet is actively open.
  static bool get isOpen => _isOpen;

  /// Displays the NowPlayingSheet modal bottom sheet if not already open.
  static Future<void> show(BuildContext context) async {
    if (_isOpen) return;
    _isOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black87,
        builder: (context) => const NowPlayingSheet(),
      );
    } finally {
      _isOpen = false;
    }
  }

  /// Creates now playing sheet.
  const NowPlayingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicPlayerController>();
    final song = controller.currentSong;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final accent = controller.dynamicAccentColor;
    final isDark = theme.brightness == Brightness.dark;
    final routeAnimation = ModalRoute.of(context)?.animation;

    final sheetContent = AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      color: theme.scaffoldBackgroundColor,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: controller.getDynamicGradient(isDark),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Google Music',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      M3EIconButton(
                        variant: M3EIconButtonVariant.tonal,
                        size: M3EIconButtonSize.sm,
                        shape: M3EIconButtonShapeVariant.square,
                        width: M3EIconButtonWidth.defaultWidth,
                        haptic: M3EHapticFeedback.light,
                        tooltip: controller.isSongDownloaded(song.id)
                            ? 'Downloaded (Tap to remove)'
                            : (controller.isSongDownloading(song.id)
                                  ? 'Downloading in progress'
                                  : 'Download for offline playback'),
                        icon: controller.isSongDownloading(song.id)
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: M3EProgressIndicator.circular(
                                  value: controller.getSongDownloadProgress(
                                    song.id,
                                  ),
                                  strokeWidth: 2,
                                  trackStrokeWidth: 2,
                                  trackColor: colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                  color: accent,
                                ),
                              )
                            : Icon(
                                controller.isSongDownloaded(song.id)
                                    ? Icons.download_done_rounded
                                    : Icons.download_for_offline_outlined,
                                color: controller.isSongDownloaded(song.id)
                                    ? accent
                                    : null,
                                size: 20,
                              ),
                        onPressed: () async {
                          if (controller.isSongDownloading(song.id)) {
                            return;
                          }
                          if (controller.isSongDownloaded(song.id)) {
                            final removed = await controller.removeDownload(
                              song.id,
                            );
                            if (context.mounted && removed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Removed "${song.title}" from downloads',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } else {
                            await controller.downloadSong(song);
                          }
                        },
                      ),

                      M3EIconButton(
                        variant: M3EIconButtonVariant.tonal,
                        size: M3EIconButtonSize.sm,
                        shape: M3EIconButtonShapeVariant.square,
                        width: M3EIconButtonWidth.defaultWidth,
                        haptic: M3EHapticFeedback.light,
                        tooltip: controller.isSongLiked(song.id)
                            ? 'Unlike'
                            : 'Favorite',
                        icon: Icon(
                          controller.isSongLiked(song.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: controller.isSongLiked(song.id)
                              ? accent
                              : null,
                          size: 20,
                        ),
                        onPressed: () => controller.toggleLike(song),
                      ),

                      M3EIconButton(
                        variant: M3EIconButtonVariant.tonal,
                        size: M3EIconButtonSize.sm,
                        shape: M3EIconButtonShapeVariant.square,
                        width: M3EIconButtonWidth.defaultWidth,
                        haptic: M3EHapticFeedback.light,
                        tooltip: controller.isSleepTimerActive
                            ? 'Sleep Timer Active'
                            : 'Sleep Timer',
                        icon: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            Icon(
                              controller.isSleepTimerActive
                                  ? Icons.bedtime_rounded
                                  : Icons.bedtime_outlined,
                              color: controller.isSleepTimerActive
                                  ? accent
                                  : null,
                              size: 20,
                            ),
                            if (controller.isSleepTimerActive)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () => SleepTimerSheet.show(context),
                      ),
                    ],
                  ),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: <Widget>[
                    const Spacer(flex: DateTime.april),
                    Center(
                      child: M3EAlbumArt(
                        imageUrl: song.thumbnailUrl,
                        aspectRatio: 1.0,
                        radius: 12,
                        elevation: 2,
                        glowColor: accent,
                      ),
                    ),
                    const Spacer(flex: DateTime.august),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        M3EMarqueeText(
                          text: song.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ValueListenableBuilder<Duration>(
                          valueListenable: controller.positionNotifier,
                          builder: (context, currentPosition, child) {
                            return WavySlider(
                              position: currentPosition,
                              duration: controller.duration,
                              isPlaying: controller.isPlaying,
                              activeColor: accent,
                              inactiveColor: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.black.withValues(alpha: 0.08),
                              onSeek: controller.seek,
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(flex: DateTime.december),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        M3EIconButton(
                          variant: M3EIconButtonVariant.tonal,
                          size: M3EIconButtonSize.sm,
                          shape: M3EIconButtonShapeVariant.square,
                          width: M3EIconButtonWidth.defaultWidth,
                          haptic: M3EHapticFeedback.light,
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: controller.isShuffle
                                ? accent
                                : colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          onPressed: controller.toggleShuffle,
                        ),
                        M3EIconButton(
                          variant: M3EIconButtonVariant.tonal,
                          size: M3EIconButtonSize.md,
                          shape: M3EIconButtonShapeVariant.square,
                          width: M3EIconButtonWidth.defaultWidth,
                          haptic: M3EHapticFeedback.light,
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            size: 34,
                          ),
                          onPressed: controller.playPrevious,
                        ),
                        GestureDetector(
                          onTap: controller.togglePlayPause,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.12,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: controller.status == PlayerStatus.loading
                                  ? SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: M3EProgressIndicator.circularWavy(
                                        strokeWidth: 3.0,
                                        trackStrokeWidth: 3.0,
                                        color: accent.computeLuminance() > 0.45
                                            ? const Color(0xFF161616)
                                            : Colors.white,
                                        trackColor:
                                            (accent.computeLuminance() > 0.45
                                                    ? const Color(0xFF161616)
                                                    : Colors.white)
                                                .withValues(alpha: 0.22),
                                      ),
                                    )
                                  : Icon(
                                      controller.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: accent.computeLuminance() > 0.45
                                          ? const Color(0xFF161616)
                                          : Colors.white,
                                      size: 36,
                                    ),
                            ),
                          ),
                        ),
                        M3EIconButton(
                          variant: M3EIconButtonVariant.tonal,
                          size: M3EIconButtonSize.md,
                          shape: M3EIconButtonShapeVariant.square,
                          width: M3EIconButtonWidth.defaultWidth,
                          haptic: M3EHapticFeedback.light,
                          icon: const Icon(Icons.skip_next_rounded, size: 34),
                          onPressed: controller.playNext,
                        ),
                        M3EIconButton(
                          variant: M3EIconButtonVariant.tonal,
                          size: M3EIconButtonSize.sm,
                          shape: M3EIconButtonShapeVariant.square,
                          width: M3EIconButtonWidth.defaultWidth,
                          haptic: M3EHapticFeedback.light,
                          icon: Icon(
                            controller.loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: controller.loopMode != LoopMode.off
                                ? accent
                                : colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          onPressed: controller.cycleRepeatMode,
                        ),
                      ],
                    ),

                    const Spacer(flex: DateTime.december),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: M3EButtonGroup(
                        type: M3EButtonGroupType.connected,
                        shape: M3EButtonShape.round,
                        size: M3EButtonSize.sm,
                        style: M3EButtonStyle.tonal,
                        neighborSquish: true,
                        onSelectedIndexChanged: (int? index) {
                          if (index == 0) {
                            QueueBottomSheet.showUpNext(context);
                          } else if (index == 1) {
                            QueueBottomSheet.showLyrics(context);
                          } else if (index == 2) {
                            QueueBottomSheet.showRelated(context);
                          }
                        },
                        actions: const <M3EButtonGroupAction>[
                          M3EButtonGroupAction(
                            label: Text(
                              'UP NEXT',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          M3EButtonGroupAction(
                            label: Text(
                              'LYRICS',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          M3EButtonGroupAction(
                            label: Text(
                              'RELATED',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: routeAnimation ?? const AlwaysStoppedAnimation<double>(1.0),
      builder: (context, child) {
        final animValue = routeAnimation?.value ?? 1.0;
        final progress = ((animValue - 0.96) / 0.04).clamp(0.0, 1.0);
        final topRadius = 12.0 * (1.0 - progress);

        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
          child: child,
        );
      },
      child: sheetContent,
    );
  }
}
