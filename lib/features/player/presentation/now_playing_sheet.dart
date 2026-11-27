import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/audio_route_service.dart';
import '../../../core/audio/music_player_controller.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../core/widgets/wavy_slider.dart';
import '../../../models/playback_state.dart';
import '../../../models/song_model.dart';
import 'audio_output_sheet.dart';
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
        barrierColor: Colors.transparent,
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          maxWidth: double.infinity,
        ),
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth > 750;

    final sheetContent = SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: AnimatedContainer(
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
              padding: EdgeInsets.only(top: isDesktop ? 12 : 50),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(isDesktop ? 60 : 50),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 36 : 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Google Music',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: isDesktop ? 26 : 24,
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
                                    trackColor: colorScheme.onSurface
                                        .withValues(alpha: 0.2),
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
                body: isDesktop
                    ? _buildDesktopBody(
                        context,
                        controller,
                        song,
                        theme,
                        colorScheme,
                        accent,
                        isDark,
                      )
                    : _buildMobileBody(
                        context,
                        controller,
                        song,
                        theme,
                        colorScheme,
                        accent,
                        isDark,
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
        final topRadius = isDesktop ? 0.0 : 12.0 * (1.0 - progress);

        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
          child: child,
        );
      },
      child: sheetContent,
    );
  }

  Widget _buildMobileBody(
    BuildContext context,
    MusicPlayerController controller,
    SongModel song,
    ThemeData theme,
    ColorScheme colorScheme,
    Color accent,
    bool isDark,
  ) {
    return Padding(
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
          const Spacer(flex: 8),
          _buildControlsRow(controller, accent, isDark, colorScheme),
          const Spacer(flex: 6),
          _buildAudioRoutePill(context, accent, isDark, colorScheme),
          const Spacer(flex: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildButtonGroup(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    MusicPlayerController controller,
    SongModel song,
    ThemeData theme,
    ColorScheme colorScheme,
    Color accent,
    bool isDark,
  ) {
    final size = MediaQuery.sizeOf(context);
    final artSize = (size.height * 0.52).clamp(280.0, 480.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: artSize,
                      maxHeight: artSize,
                    ),
                    child: M3EAlbumArt(
                      imageUrl: song.thumbnailUrl,
                      aspectRatio: 1.0,
                      radius: 20,
                      elevation: 6,
                      glowColor: accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    M3EMarqueeText(
                      text: song.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                    const SizedBox(height: 28),
                    _buildControlsRow(controller, accent, isDark, colorScheme),
                    const SizedBox(height: 22),
                    Center(
                      child: _buildAudioRoutePill(
                        context,
                        accent,
                        isDark,
                        colorScheme,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(child: _buildButtonGroup(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioRoutePill(
    BuildContext context,
    Color accent,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return ValueListenableBuilder<AudioRouteInfo>(
      valueListenable: AudioRouteService.instance.currentRouteNotifier,
      builder: (context, route, child) {
        final isExternal = route.type != AudioRouteType.speaker;

        return InkWell(
          onTap: () => AudioOutputSheet.show(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isExternal
                  ? accent.withValues(alpha: isDark ? 0.22 : 0.14)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  route.icon,
                  size: 13,
                  color: isExternal ? accent : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    route.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isExternal ? accent : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsRow(
    MusicPlayerController controller,
    Color accent,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Row(
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
            color: controller.isShuffle ? accent : colorScheme.onSurfaceVariant,
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
          icon: const Icon(Icons.skip_previous_rounded, size: 34),
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
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
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
    );
  }

  Widget _buildButtonGroup(BuildContext context) {
    return M3EButtonGroup(
      type: M3EButtonGroupType.connected,
      shape: M3EButtonShape.round,
      size: M3EButtonSize.sm,
      style: M3EButtonStyle.tonal,
      neighborSquish: false,
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
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
        ),
        M3EButtonGroupAction(
          label: Text(
            'LYRICS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
        ),
        M3EButtonGroupAction(
          label: Text(
            'RELATED',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
