import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../models/song_model.dart';
import '../../playlist/presentation/playlist_detail_screen.dart';

/// User personal music library containing playlists, liked songs, downloads, and history.
class LibraryScreen extends StatefulWidget {
  /// Callback when user taps search in the top bar.
  final VoidCallback? onSearchTapped;

  /// Creates library screen.
  const LibraryScreen({super.key, this.onSearchTapped});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeTab = 'All';

  final List<String> _tabs = const <String>[
    'All',
    'Playlists',
    'Liked',
    'Downloaded',
    'History',
  ];

  @override
  Widget build(BuildContext context) {
    final m3eTheme = M3ETheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = m3eTheme.colorScheme;
    final controller = context.watch<MusicPlayerController>();

    final liked = controller.likedSongs;
    final history = controller.history;
    final downloaded = controller.downloadedSongs;
    final playlists = controller.playlists;
    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final hPad = isDesktop ? 24.0 : 12.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        titleSpacing: hPad,
        elevation: 0,
        title: Text(
          'Library',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search Songs',
            color: colorScheme.onSurface,
            onPressed: widget.onSearchTapped,
          ),
          SizedBox(width: isDesktop ? 18 : 6),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                itemCount: _tabs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isSelected = tab == _activeTab;
                  return M3EChip(
                    label: tab,
                    type: M3EChipType.filter,
                    selected: isSelected,
                    onPressed: () {
                      setState(() {
                        _activeTab = tab;
                      });
                    },
                  );
                },
              ),
            ),
          ),
          if (_activeTab == 'All' || _activeTab == 'Playlists') ...<Widget>[
            if (playlists.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Playlists',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () =>
                            _showCreatePlaylistDialog(context, controller),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: controller.dynamicAccentColor.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.add_rounded,
                                size: 15,
                                color: controller.dynamicAccentColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: controller.dynamicAccentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: M3EList(
                    color: colorScheme.surfaceContainerHighest,
                    outerRadius: 12,
                    innerRadius: 4,
                    gap: 2,
                    itemCount: playlists.length,
                    onTap: (int index) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => PlaylistDetailScreen(
                            playlistId: playlists[index].id,
                          ),
                        ),
                      );
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final playlist = playlists[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: playlist.thumbnailUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        playlist.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, err, stack) =>
                                            Icon(
                                              Icons.queue_music_rounded,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              size: 22,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.queue_music_rounded,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 22,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    playlist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        '${playlist.trackCount} songs',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (controller.isPlaylistFullyDownloaded(
                                          playlist.songs)) ...<Widget>[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.download_done_rounded,
                                          size: 13,
                                          color: controller.dynamicAccentColor,
                                        ),
                                      ] else if (controller
                                          .isPlaylistDownloading(
                                              playlist.songs)) ...<Widget>[
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color:
                                                controller.dynamicAccentColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.play_arrow_rounded,
                                color: controller.dynamicAccentColor,
                                size: 24,
                              ),
                              tooltip: 'Play Playlist',
                              onPressed: () =>
                                  controller.playPlaylist(playlist),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ] else if (_activeTab == 'Playlists') ...<Widget>[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.queue_music_rounded,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No playlists yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create custom playlists like "Gym Vibes" or "Late Night Chill"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: controller.dynamicAccentColor,
                            foregroundColor:
                                controller.dynamicAccentColor
                                        .computeLuminance() >
                                    0.5
                                ? Colors.black
                                : Colors.white,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Playlist'),
                          onPressed: () =>
                              _showCreatePlaylistDialog(context, controller),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (_activeTab == 'All' || _activeTab == 'Liked') ...<Widget>[
            if (liked.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 10),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'Liked music',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: M3EList(
                    color: colorScheme.surfaceContainerHighest,
                    outerRadius: 12,
                    innerRadius: 4,
                    gap: 2,
                    itemCount: liked.length,
                    onTap: (int index) {
                      M3ESongTile.handleTap(
                        context,
                        liked[index],
                        queue: liked,
                      );
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return M3ESongTile(song: liked[index]);
                    },
                  ),
                ),
              ),
            ],
          ],
          if (_activeTab == 'All' || _activeTab == 'Downloaded') ...<Widget>[
            if (downloaded.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Downloaded music',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: controller.dynamicAccentColor.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              controller.offlineService.formattedStorageUsed,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: controller.dynamicAccentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: M3EList(
                    color: colorScheme.surfaceContainerHighest,
                    outerRadius: 12,
                    innerRadius: 4,
                    gap: 2,
                    itemCount: downloaded.length,
                    onTap: (int index) {
                      M3ESongTile.handleTap(
                        context,
                        downloaded[index],
                        queue: downloaded,
                      );
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final item = downloaded[index];
                      return M3ESongTile(
                        song: item,
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () =>
                              _confirmRemoveDownload(context, controller, item),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ] else if (_activeTab == 'Downloaded') ...<Widget>[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.download_for_offline_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No downloaded music',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Save songs for offline listening by tapping the download option on any track',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (_activeTab == 'All' || _activeTab == 'History') ...<Widget>[
            if (history.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 10),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'Recently played',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: M3EList(
                    color: colorScheme.surfaceContainerHighest,
                    outerRadius: 12,
                    innerRadius: 4,
                    gap: 2,
                    itemCount: history.length,
                    onTap: (int index) {
                      M3ESongTile.handleTap(
                        context,
                        history[index],
                        queue: history,
                      );
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return M3ESongTile(song: history[index]);
                    },
                  ),
                ),
              ),
            ],
          ],
          if (liked.isEmpty &&
              history.isEmpty &&
              downloaded.isEmpty &&
              playlists.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.library_music_rounded,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your library is empty',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Like or download songs to find them quickly here',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }

  /// Displays confirmation dialog to remove downloaded song from offline storage.
  void _confirmRemoveDownload(
    BuildContext context,
    MusicPlayerController controller,
    SongModel song,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = controller.dynamicAccentColor;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 24,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(Icons.delete_outline_rounded, color: accent, size: 28),
          title: Text(
            'Remove Download?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Text(
              'Remove "${song.title}" from offline storage? You can always download it again later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                Navigator.of(context).pop();
                await controller.removeDownload(song.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Removed "${song.title}" from offline music',
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
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  /// Displays dialog to create a new custom playlist.
  void _showCreatePlaylistDialog(
    BuildContext context,
    MusicPlayerController controller,
  ) {
    final textController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final accent = controller.dynamicAccentColor;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 24,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'New Playlist',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Playlist name (e.g. Gym Vibes)',
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
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  final created = await controller.createPlaylist(name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created playlist "${created.name}"'),
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
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
