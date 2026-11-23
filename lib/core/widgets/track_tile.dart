import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../audio/music_player_controller.dart';
import '../../models/song_model.dart';
import 'm3e_widgets.dart';
import 'track_options_sheet.dart';

/// Unified Google Music song list tile matching the HomeScreen expressive design.
class M3ESongTile extends StatelessWidget {
  /// The song model to render.
  final SongModel song;

  /// Optional playlist queue context for playback.
  final List<SongModel>? queue;

  /// Optional explicit tap callback.
  final VoidCallback? onTap;

  /// Whether to show "Top match • " prefix before the artist in the subtitle.
  final bool isPersonalPick;

  /// Optional custom subtitle string override.
  final String? subtitle;

  /// Optional custom trailing widget override.
  final Widget? trailing;

  /// Tile padding. Defaults to `EdgeInsets.symmetric(horizontal: 14, vertical: 10)` matching HomeScreen.
  final EdgeInsetsGeometry padding;

  /// Whether this tile should render its own standalone Material container
  /// with rounded corners and InkWell (useful when outside [M3EList]).
  final bool isStandalone;

  /// Whether to enable direct ink tap response when [onTap] is null and not standalone.
  final bool interactive;

  /// Creates a unified song tile.
  const M3ESongTile({
    super.key,
    required this.song,
    this.queue,
    this.onTap,
    this.isPersonalPick = false,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.isStandalone = false,
    this.interactive = false,
  });

  /// Standard tap handler that toggles play/pause if already active, or plays [song] with [queue].
  static void handleTap(
    BuildContext context,
    SongModel song, {
    List<SongModel>? queue,
  }) {
    final controller = context.read<MusicPlayerController>();
    if (controller.currentSong?.id == song.id) {
      if (controller.isPlaying) {
        controller.pause();
      } else {
        controller.resume();
      }
    } else {
      controller.playSong(song, newQueue: queue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = context.select<MusicPlayerController, bool>(
      (c) => c.currentSong?.id == song.id,
    );
    final isPlaying = isCurrent &&
        context.select<MusicPlayerController, bool>(
          (c) => c.isPlaying,
        );
    final isDownloaded = context.select<MusicPlayerController, bool>(
      (c) => c.isSongDownloaded(song.id),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeAccent = context.select<MusicPlayerController, Color>(
      (c) => c.getLegibleAccentColor(isDark),
    );

    final effectiveSubtitle =
        subtitle ??
        (isPersonalPick
            ? 'Top match • ${song.artist} • ${song.duration}'
            : '${song.artist} • ${song.duration}');

    final content = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              M3EAlbumArt(imageUrl: song.thumbnailUrl, size: 42, radius: 4),
              if (isPlaying)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(child: M3EWaveformBars(color: activeAccent)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                isCurrent
                    ? M3EMarqueeText(
                        text: song.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: -0.1,
                          color: activeAccent,
                        ),
                      )
                    : Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: -0.1,
                          color: colorScheme.onSurface,
                        ),
                      ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (isDownloaded) ...<Widget>[
                      Icon(
                        Icons.download_done_rounded,
                        size: 12,
                        color: activeAccent,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        effectiveSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: isCurrent ? activeAccent : colorScheme.onSurfaceVariant,
              ),
              onPressed: () => TrackOptionsSheet.show(context, song),
            ),
        ],
      ),
    );

    if (isStandalone) {
      return Material(
        color: isCurrent
            ? activeAccent.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap ?? () => handleTap(context, song, queue: queue),
          onLongPress: () => TrackOptionsSheet.show(context, song),
          borderRadius: BorderRadius.circular(10),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        onLongPress: () => TrackOptionsSheet.show(context, song),
        borderRadius: BorderRadius.circular(4),
        child: content,
      );
    }

    if (interactive) {
      return InkWell(
        onTap: () => handleTap(context, song, queue: queue),
        onLongPress: () => TrackOptionsSheet.show(context, song),
        borderRadius: BorderRadius.circular(4),
        child: content,
      );
    }

    return content;
  }
}

/// Convenience alias matching [M3ESongTile].
typedef TrackTile = M3ESongTile;
