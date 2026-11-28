import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../audio/music_player_controller.dart';
import '../../features/player/presentation/sleep_timer_sheet.dart';
import '../../features/playlist/presentation/add_to_playlist_sheet.dart';
import '../../models/song_model.dart';
import 'm3e_widgets.dart';

/// Modal bottom sheet presenting actions for a song track (Play Next, Add to Playlist, Download, Favorite).
class TrackOptionsSheet extends StatelessWidget {
  /// The song target for options.
  final SongModel song;

  /// Creates a track options bottom sheet.
  const TrackOptionsSheet({super.key, required this.song});

  /// Opens the [TrackOptionsSheet] as an expressive modal bottom sheet.
  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      builder: (context) => TrackOptionsSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();
    final accent = controller.dynamicAccentColor;
    final isDownloaded = controller.isSongDownloaded(song.id);
    final isDownloading = controller.isSongDownloading(song.id);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                M3EAlbumArt(imageUrl: song.thumbnailUrl, size: 46, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 6),
            _buildOptionTile(
              context: context,
              icon: Icons.playlist_add_rounded,
              title: 'Add to Playlist',
              subtitle: 'Save track to your custom playlists',
              accent: accent,
              colorScheme: colorScheme,
              onTap: () {
                Navigator.of(context).pop();
                AddToPlaylistSheet.show(context, song);
              },
            ),
            _buildOptionTile(
              context: context,
              icon: isDownloaded
                  ? Icons.download_done_rounded
                  : (isDownloading
                        ? Icons.downloading_rounded
                        : Icons.download_for_offline_outlined),
              title: isDownloaded
                  ? 'Remove from Offline'
                  : (isDownloading ? 'Downloading...' : 'Download for Offline'),
              subtitle: isDownloaded
                  ? 'Delete local audio file to save space'
                  : 'Play track with zero internet or buffering',
              accent: isDownloaded ? accent : null,
              colorScheme: colorScheme,
              onTap: () async {
                Navigator.of(context).pop();
                if (isDownloaded) {
                  await controller.removeDownload(song.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Removed "${song.title}" from offline downloads',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                } else if (!isDownloading) {
                  await controller.downloadSong(song);
                }
              },
            ),
            _buildOptionTile(
              context: context,
              icon: controller.isSongLiked(song.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              title: controller.isSongLiked(song.id)
                  ? 'Remove from Liked'
                  : 'Add to Liked',
              subtitle: controller.isSongLiked(song.id)
                  ? 'Saved in your favorites library'
                  : 'Mark as a favorite track',
              accent: controller.isSongLiked(song.id) ? accent : null,
              colorScheme: colorScheme,
              onTap: () {
                Navigator.of(context).pop();
                controller.toggleLike(song);
              },
            ),
            _buildOptionTile(
              context: context,
              icon: controller.isSleepTimerActive
                  ? Icons.bedtime_rounded
                  : Icons.bedtime_outlined,
              title: 'Sleep Timer',
              subtitle: controller.isSleepTimerActive
                  ? 'Active • Tap to view or change'
                  : 'Stop music automatically',
              accent: controller.isSleepTimerActive ? accent : null,
              colorScheme: colorScheme,
              onTap: () {
                Navigator.of(context).pop();
                SleepTimerSheet.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    Color? accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        M3EHaptics.trigger(M3EHapticFeedback.light);
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: accent ?? colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: accent ?? colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
