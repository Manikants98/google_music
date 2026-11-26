import 'package:flutter/material.dart';
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

    return AnimatedContainer(
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
                preferredSize: const Size.fromHeight(52),
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
                        variant: M3EIconButtonVariant.filled,
                        size: M3EIconButtonSize.sm,
                        shape: M3EIconButtonShapeVariant.square,
                        width: M3EIconButtonWidth.defaultWidth,
                        haptic: M3EHapticFeedback.light,
                        tooltip: controller.isSongDownloaded(song.id)
                            ? 'Downloaded (Tap to remove)'
                            : (controller.isSongDownloading(song.id)
                                  ? 'Downloading in progress'
                                  : 'Download for offline playback'),
                        decoration: M3EIconButtonDecoration(
                          backgroundColor: WidgetStateProperty.all(
                            controller.isSongDownloaded(song.id)
                                ? accent.withValues(alpha: isDark ? 0.28 : 0.20)
                                : (isDark
                                      ? Color.alphaBlend(
                                          accent.withValues(alpha: 0.14),
                                          const Color(0xFF202020),
                                        )
                                      : Color.alphaBlend(
                                          accent.withValues(alpha: 0.10),
                                          const Color(0xFFECEEF4),
                                        )),
                          ),
                          foregroundColor: WidgetStateProperty.all(
                            controller.isSongDownloaded(song.id)
                                ? accent
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : colorScheme.onSurface),
                          ),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color: controller.isSongDownloaded(song.id)
                                  ? accent.withValues(
                                      alpha: isDark ? 0.45 : 0.35,
                                    )
                                  : accent.withValues(
                                      alpha: isDark ? 0.18 : 0.12,
                                    ),
                              width: 1.0,
                            ),
                          ),
                        ),
                        icon: controller.isSongDownloading(song.id)
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  value: controller.getSongDownloadProgress(
                                    song.id,
                                  ),
                                  strokeWidth: 2.2,
                                  color: accent,
                                  backgroundColor: accent.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              )
                            : Icon(
                                controller.isSongDownloaded(song.id)
                                    ? Icons.download_done_rounded
                                    : Icons.download_for_offline_outlined,
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
                      const SizedBox(width: 8),
                      M3EIconButton(
                        variant: M3EIconButtonVariant.filled,
                        size: M3EIconButtonSize.sm,
                        shape: M3EIconButtonShapeVariant.square,
                        width: M3EIconButtonWidth.defaultWidth,
                        haptic: M3EHapticFeedback.light,
                        tooltip: controller.isSongLiked(song.id)
                            ? 'Unlike'
                            : 'Favorite',
                        decoration: M3EIconButtonDecoration(
                          backgroundColor: WidgetStateProperty.all(
                            controller.isSongLiked(song.id)
                                ? accent.withValues(alpha: isDark ? 0.28 : 0.20)
                                : (isDark
                                      ? Color.alphaBlend(
                                          accent.withValues(alpha: 0.14),
                                          const Color(0xFF202020),
                                        )
                                      : Color.alphaBlend(
                                          accent.withValues(alpha: 0.10),
                                          const Color(0xFFECEEF4),
                                        )),
                          ),
                          foregroundColor: WidgetStateProperty.all(
                            controller.isSongLiked(song.id)
                                ? accent
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : colorScheme.onSurface),
                          ),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color: controller.isSongLiked(song.id)
                                  ? accent.withValues(
                                      alpha: isDark ? 0.45 : 0.35,
                                    )
                                  : accent.withValues(
                                      alpha: isDark ? 0.18 : 0.12,
                                    ),
                              width: 1.0,
                            ),
                          ),
                        ),
                        icon: Icon(
                          controller.isSongLiked(song.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                        ),
                        onPressed: () => controller.toggleLike(song),
                      ),
                      const SizedBox(width: 8),
                      M3EIconButton(
                        variant: M3EIconButtonVariant.filled,
                        size: M3EIconButtonSize.sm,
                        shape: M3EIconButtonShapeVariant.square,
                        width: M3EIconButtonWidth.defaultWidth,
                        haptic: M3EHapticFeedback.light,
                        tooltip: controller.isSleepTimerActive
                            ? 'Sleep Timer Active'
                            : 'Sleep Timer',
                        decoration: M3EIconButtonDecoration(
                          backgroundColor: WidgetStateProperty.all(
                            controller.isSleepTimerActive
                                ? accent.withValues(alpha: isDark ? 0.28 : 0.20)
                                : (isDark
                                      ? Color.alphaBlend(
                                          accent.withValues(alpha: 0.14),
                                          const Color(0xFF202020),
                                        )
                                      : Color.alphaBlend(
                                          accent.withValues(alpha: 0.10),
                                          const Color(0xFFECEEF4),
                                        )),
                          ),
                          foregroundColor: WidgetStateProperty.all(
                            controller.isSleepTimerActive
                                ? accent
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : colorScheme.onSurface),
                          ),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color: controller.isSleepTimerActive
                                  ? accent.withValues(
                                      alpha: isDark ? 0.45 : 0.35,
                                    )
                                  : accent.withValues(
                                      alpha: isDark ? 0.18 : 0.12,
                                    ),
                              width: 1.0,
                            ),
                          ),
                        ),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            Icon(
                              controller.isSleepTimerActive
                                  ? Icons.bedtime_rounded
                                  : Icons.bedtime_outlined,
                              size: 20,
                            ),
                            if (controller.isSleepTimerActive)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      width: 1.2,
                                    ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Center(
                      child: M3EAlbumArt(
                        imageUrl: song.thumbnailUrl,
                        aspectRatio: 1.0,
                        radius: 12,
                        elevation: 2,
                      ),
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: controller.isShuffle
                                ? accent
                                : colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          onPressed: controller.toggleShuffle,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            size: 34,
                          ),
                          onPressed: controller.playPrevious,
                        ),
                        GestureDetector(
                          onTap: controller.togglePlayPause,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
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
                                      child: M3EProgressIndicator.circular(
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
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 34),
                          onPressed: controller.playNext,
                        ),
                        IconButton(
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: M3EButtonGroup(
                        type: M3EButtonGroupType.connected,
                        shape: M3EButtonShape.round,
                        size: M3EButtonSize.sm,
                        style: M3EButtonStyle.filled,
                        neighborSquish: true,
                        decoration: M3EButtonDecoration(
                          backgroundColor: WidgetStateProperty.all(
                            isDark
                                ? Color.alphaBlend(
                                    accent.withValues(alpha: 0.18),
                                    const Color(0xFF1E1E1E),
                                  )
                                : Color.alphaBlend(
                                    accent.withValues(alpha: 0.12),
                                    const Color(0xFFE8EAF2),
                                  ),
                          ),
                          foregroundColor: WidgetStateProperty.all(
                            isDark ? Colors.white : const Color(0xFF191C1E),
                          ),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color: accent.withValues(
                                alpha: isDark ? 0.24 : 0.18,
                              ),
                              width: 1.0,
                            ),
                          ),
                        ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
