import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../core/widgets/track_tile.dart';
import '../../../models/playlist_model.dart';
import '../../../models/song_model.dart';
import '../../player/presentation/now_playing_sheet.dart';

/// Detailed view for a custom user playlist displaying tracks, playback actions, and management controls.
class PlaylistDetailScreen extends StatelessWidget {
  /// The ID of the playlist to display.
  final String playlistId;

  /// Creates a playlist detail screen.
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();
    final accent = controller.dynamicAccentColor;

    final playlist = controller.playlists.cast<PlaylistModel?>().firstWhere(
      (PlaylistModel? p) => p?.id == playlistId,
      orElse: () => null,
    );

    if (playlist == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(backgroundColor: colorScheme.surface, elevation: 0),
        body: const Center(child: Text('Playlist not found')),
      );
    }

    final songs = playlist.songs;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename Playlist',
            onPressed: () => _showRenameDialog(context, controller, playlist),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Playlist',
            onPressed: () =>
                _confirmDeletePlaylist(context, controller, playlist),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: playlist.thumbnailUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                playlist.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, err, stack) => Icon(
                                  Icons.queue_music_rounded,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.queue_music_rounded,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    playlist.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '${playlist.trackCount} songs',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (controller.isPlaylistFullyDownloaded(
                        songs,
                      )) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.download_done_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Downloaded',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else if (controller.isPlaylistDownloading(
                        songs,
                      )) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Downloading (${controller.getPlaylistDownloadedCount(songs)}/${songs.length})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (songs.isNotEmpty) ...<Widget>[
                    Builder(
                      builder: (context) {
                        final downloadedCount = controller
                            .getPlaylistDownloadedCount(songs);
                        final isFullyDownloaded = controller
                            .isPlaylistFullyDownloaded(songs);
                        final isDownloading = controller.isPlaylistDownloading(
                          songs,
                        );
                        final remaining = songs.length - downloadedCount;

                        return M3EButtonGroup(
                          type: M3EButtonGroupType.connected,
                          size: M3EButtonSize.sm,
                          style: M3EButtonStyle.tonal,
                          neighborSquish: false,
                          onSelectedIndexChanged: (int? index) {
                            if (index == 0) {
                              controller.playPlaylist(playlist, shuffle: false);
                              NowPlayingSheet.show(context);
                            } else if (index == 1) {
                              controller.playPlaylist(playlist, shuffle: true);
                              NowPlayingSheet.show(context);
                            } else if (index == 2) {
                              if (isFullyDownloaded) {
                                _showDownloadedOptionsSheet(
                                  context,
                                  controller,
                                  playlist,
                                  songs,
                                  accent,
                                );
                              } else if (isDownloading) {
                                _confirmCancelBatch(
                                  context,
                                  controller,
                                  downloadedCount,
                                  songs.length,
                                );
                              } else {
                                controller.downloadSongsBatch(songs);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      downloadedCount > 0
                                          ? 'Downloading $remaining remaining tracks in background...'
                                          : 'Downloading ${songs.length} tracks in background...',
                                    ),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          actions: <M3EButtonGroupAction>[
                            M3EButtonGroupAction(
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 20,
                              ),
                              label: const Text('Play All'),
                              decoration: M3EButtonDecoration(
                                foregroundColor: WidgetStateProperty.all(
                                  accent.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                            M3EButtonGroupAction(
                              icon: const Icon(Icons.shuffle_rounded, size: 18),
                              label: const Text('Shuffle'),
                            ),
                            M3EButtonGroupAction(
                              icon: isDownloading
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accent,
                                      ),
                                    )
                                  : Icon(
                                      isFullyDownloaded
                                          ? Icons.download_done_rounded
                                          : Icons.download_rounded,
                                      size: 18,
                                      color: isFullyDownloaded ? accent : null,
                                    ),
                              label: Text(
                                isFullyDownloaded
                                    ? 'Saved'
                                    : (isDownloading
                                          ? '$downloadedCount/${songs.length}'
                                          : (downloadedCount > 0
                                                ? '$remaining left'
                                                : 'Download')),
                                style: TextStyle(
                                  color: isFullyDownloaded ? accent : null,
                                ),
                              ),
                              decoration: M3EButtonDecoration(
                                backgroundColor: WidgetStateProperty.all(
                                  isFullyDownloaded
                                      ? accent.withValues(alpha: 0.16)
                                      : null,
                                ),
                                foregroundColor: WidgetStateProperty.all(
                                  isFullyDownloaded
                                      ? accent
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (controller.isPlaylistDownloading(songs)) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Downloading offline (${controller.getPlaylistDownloadedCount(songs)} of ${songs.length} saved)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _confirmCancelBatch(
                                    context,
                                    controller,
                                    controller.getPlaylistDownloadedCount(
                                      songs,
                                    ),
                                    songs.length,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: colorScheme.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: songs.isEmpty
                                    ? 0.0
                                    : (controller.getPlaylistDownloadedCount(
                                                songs,
                                              ) /
                                              songs.length)
                                          .clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: colorScheme.surfaceContainer,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.music_off_rounded,
                        size: 56,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This playlist is empty',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add songs from Home, Search, or Library using the 3-dot options menu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverToBoxAdapter(
                child: M3EList(
                  color: colorScheme.surfaceContainerHighest,
                  outerRadius: 12,
                  innerRadius: 4,
                  gap: 2,
                  itemCount: songs.length,
                  onTap: (int index) {
                    controller.playPlaylist(playlist, startIndex: index);
                    NowPlayingSheet.show(context);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final song = songs[index];
                    return M3ESongTile(
                      song: song,
                      trailing: IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Remove from playlist',
                        onPressed: () async {
                          await controller.removeSongFromPlaylist(
                            playlist.id,
                            song.id,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Removed "${song.title}" from "${playlist.name}"',
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  /// Displays dialog to rename the current playlist.
  void _showRenameDialog(
    BuildContext context,
    MusicPlayerController controller,
    PlaylistModel playlist,
  ) {
    final textController = TextEditingController(text: playlist.name);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = controller.dynamicAccentColor;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Rename Playlist',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Playlist name',
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: accent.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final newName = textController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  await controller.renamePlaylist(playlist.id, newName);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Displays confirmation dialog to delete the playlist entirely.
  void _confirmDeletePlaylist(
    BuildContext context,
    MusicPlayerController controller,
    PlaylistModel playlist,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = controller.dynamicAccentColor;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(Icons.delete_outline_rounded, color: accent, size: 28),
          title: Text(
            'Delete "${playlist.name}"?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Text(
              'Are you sure you want to delete this playlist? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: accent.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
                await controller.deletePlaylist(playlist.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted "${playlist.name}"'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Displays modal options sheet when all playlist tracks are downloaded offline.
  void _showDownloadedOptionsSheet(
    BuildContext context,
    MusicPlayerController controller,
    PlaylistModel playlist,
    List<SongModel> songs,
    Color accent,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download_done_rounded,
                  color: accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Playlist Downloaded',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All ${songs.length} tracks are saved on this device for offline playback.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(Icons.play_circle_fill_rounded, color: accent),
                title: const Text(
                  'Play Offline Now',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Plays cached files with zero data usage'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  controller.playPlaylist(playlist, shuffle: false);
                  NowPlayingSheet.show(context);
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  Icons.delete_sweep_outlined,
                  color: colorScheme.error,
                ),
                title: Text(
                  'Remove Playlist Downloads',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Frees device storage taken by these songs',
                ),
                onTap: () async {
                  Navigator.of(bottomSheetContext).pop();
                  final List<String> songIds = songs
                      .map((SongModel s) => s.id)
                      .toList();
                  await controller.removeDownloadsBatch(songIds);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Removed offline downloads for "${playlist.name}"',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Displays confirmation dialog to abort ongoing batch download queue.
  void _confirmCancelBatch(
    BuildContext context,
    MusicPlayerController controller,
    int downloadedCount,
    int totalCount,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = controller.dynamicAccentColor;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(Icons.cancel_outlined, color: accent, size: 28),
          title: const Text(
            'Cancel Batch Download?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '$downloadedCount of $totalCount songs are saved. Stopping now will cancel remaining songs in the download queue.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Keep Downloading',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                controller.cancelAllBatchDownloads();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Batch download cancelled'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Cancel Download'),
            ),
          ],
        );
      },
    );
  }
}
