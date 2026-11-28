import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../models/song_model.dart';
import '../../playlist/presentation/playlist_detail_screen.dart';
import '../../stats/presentation/stats_screen.dart';

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
  String _activeTab = 'Library';

  final List<String> _tabs = const <String>[
    'Library',
    'Playlists',
    'Liked',
    'Downloaded',
    'History',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();

    final liked = controller.likedSongs;
    final history = controller.history;
    final downloaded = controller.downloadedSongs;
    final playlists = controller.playlists;
    final speedDials = controller.getSpeedDialSongs();

    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final hPad = isDesktop ? 24.0 : 12.0;
    final accent = controller.dynamicAccentColor;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        titleSpacing: isDesktop ? 24 : 12,
        elevation: 0,
        title: Text(
          'Library',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Listening Stats',
            color: colorScheme.onSurface,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const StatsScreen(),
                ),
              );
            },
          ),
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
          // Standard M3E Filter Chips (Identical pattern to HomeScreen)
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

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ----------------------------------------------------
          // MAIN DASHBOARD (When 'Library' tab is active)
          // ----------------------------------------------------
          if (_activeTab == 'Library') ...<Widget>[
            // Bento Grid Cards (matching app's 12dp card border radius)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              sliver: SliverToBoxAdapter(
                child: _buildBentoGrid(
                  context: context,
                  controller: controller,
                  likedCount: liked.length,
                  downloadedCount: downloaded.length,
                  historyCount: history.length,
                  playlistCount: playlists.length,
                  accent: accent,
                  colorScheme: colorScheme,
                  speedDials: speedDials,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Featured / Most Played Banner Card (12dp radius, 6dp inner art)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              sliver: SliverToBoxAdapter(
                child: _buildFeaturedMostPlayedCard(
                  context: context,
                  controller: controller,
                  speedDials: speedDials,
                  liked: liked,
                  history: history,
                  accent: accent,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ),
            ),

            // Recently Played Carousel (using app's standard section header and 136dp M3EAlbumArt)
            if (history.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context: context,
                  label: 'ACTIVITY',
                  title: 'Recently played',
                  extraAction: M3EButton(
                    decoration: const M3EButtonDecoration(
                      haptic: M3EHapticFeedback.light,
                    ),
                    label: const Text('See all'),
                    style: M3EButtonStyle.tonal,
                    size: M3EButtonSize.sm,
                    onPressed: () => setState(() => _activeTab = 'History'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 195,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    itemCount: history.take(12).length,
                    separatorBuilder: (context, index) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final song = history[index];
                      return GestureDetector(
                        onTap: () {
                          M3ESongTile.handleTap(context, song, queue: history);
                        },
                        child: SizedBox(
                          width: 136,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              M3EAlbumArt(
                                imageUrl: song.thumbnailUrl,
                                size: 136,
                                radius: 6,
                                elevation: 2,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Playlists Section Header
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                label: 'COLLECTIONS',
                title: 'Your playlists',
                extraAction: M3EButton(
                  decoration: const M3EButtonDecoration(
                    haptic: M3EHapticFeedback.light,
                  ),
                  label: const Text('New'),
                  style: M3EButtonStyle.tonal,
                  size: M3EButtonSize.sm,
                  onPressed: () => _showCreatePlaylistDialog(context, controller),
                ),
              ),
            ),

            if (playlists.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: _buildPlaylistsM3EList(
                    context: context,
                    controller: controller,
                    playlists: playlists,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: _buildEmptyPlaylistsPrompt(
                    context: context,
                    controller: controller,
                    colorScheme: colorScheme,
                    accent: accent,
                  ),
                ),
              ),
          ],

          // ----------------------------------------------------
          // DEDICATED TAB: PLAYLISTS
          // ----------------------------------------------------
          if (_activeTab == 'Playlists') ...<Widget>[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                label: 'CUSTOM MIXES',
                title: 'All playlists (${playlists.length})',
                extraAction: M3EButton(
                  decoration: const M3EButtonDecoration(
                    haptic: M3EHapticFeedback.light,
                  ),
                  label: const Text('Create'),
                  style: M3EButtonStyle.tonal,
                  size: M3EButtonSize.sm,
                  onPressed: () => _showCreatePlaylistDialog(context, controller),
                ),
              ),
            ),
            if (playlists.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: _buildPlaylistsM3EList(
                    context: context,
                    controller: controller,
                    playlists: playlists,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
              )
            else
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
                          size: 56,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No playlists yet',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create custom mixes to organize your favorite tracks',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        M3EButton(
                          decoration: const M3EButtonDecoration(
                            haptic: M3EHapticFeedback.light,
                          ),
                          label: const Text('Create Playlist'),
                          style: M3EButtonStyle.tonal,
                          onPressed: () => _showCreatePlaylistDialog(context, controller),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          // ----------------------------------------------------
          // DEDICATED TAB: LIKED SONGS
          // ----------------------------------------------------
          if (_activeTab == 'Liked') ...<Widget>[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                label: 'FAVORITES',
                title: 'Liked songs (${liked.length})',
                extraAction: liked.isNotEmpty
                    ? M3EButton(
                        decoration: const M3EButtonDecoration(
                          haptic: M3EHapticFeedback.light,
                        ),
                        label: const Text('Play all'),
                        style: M3EButtonStyle.tonal,
                        size: M3EButtonSize.sm,
                        onPressed: () => controller.playSong(liked.first, newQueue: liked),
                      )
                    : null,
              ),
            ),
            if (liked.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: M3EList(
                    color: colorScheme.surfaceContainerHighest,
                    outerRadius: 12,
                    innerRadius: 4,
                    gap: 2,
                    haptic: M3EHapticFeedback.light,
                    itemCount: liked.length,
                    onTap: (int index) {
                      M3ESongTile.handleTap(context, liked[index], queue: liked);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return M3ESongTile(song: liked[index]);
                    },
                  ),
                ),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.favorite_outline_rounded,
                        size: 56,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No liked songs yet',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap the heart icon on any song to save it here',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // ----------------------------------------------------
          // DEDICATED TAB: DOWNLOADED
          // ----------------------------------------------------
          if (_activeTab == 'Downloaded') ...<Widget>[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                label: 'OFFLINE STORAGE',
                title: 'Downloaded (${downloaded.length})',
                extraAction: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    controller.offlineService.formattedStorageUsed,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
            if (downloaded.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: M3EList(
                    color: colorScheme.surfaceContainerHighest,
                    outerRadius: 12,
                    innerRadius: 4,
                    gap: 2,
                    haptic: M3EHapticFeedback.light,
                    itemCount: downloaded.length,
                    onTap: (int index) {
                      M3ESongTile.handleTap(context, downloaded[index], queue: downloaded);
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
                          onPressed: () => _confirmRemoveDownload(context, controller, item),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.download_for_offline_outlined,
                        size: 56,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No downloaded music',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Download tracks for offline listening from the track menu',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // ----------------------------------------------------
          // DEDICATED TAB: HISTORY
          // ----------------------------------------------------
          if (_activeTab == 'History') ...<Widget>[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                label: 'LISTENING HISTORY',
                title: 'Playback history (${history.length})',
                extraAction: history.isNotEmpty
                    ? M3EButton(
                        decoration: const M3EButtonDecoration(
                          haptic: M3EHapticFeedback.light,
                        ),
                        label: const Text('Clear'),
                        style: M3EButtonStyle.tonal,
                        size: M3EButtonSize.sm,
                        onPressed: () => _confirmClearHistory(context, controller),
                      )
                    : null,
              ),
            ),
            if (history.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: M3EList(
                    color: colorScheme.surfaceContainerHighest,
                    outerRadius: 12,
                    innerRadius: 4,
                    gap: 2,
                    haptic: M3EHapticFeedback.light,
                    itemCount: history.length,
                    onTap: (int index) {
                      M3ESongTile.handleTap(context, history[index], queue: history);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return M3ESongTile(song: history[index]);
                    },
                  ),
                ),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No history yet',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Songs you play will show up here',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SECTION HEADER (App-wide unified pattern)
  // ----------------------------------------------------
  Widget _buildSectionHeader({
    required BuildContext context,
    required String label,
    required String title,
    Widget? extraAction,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 850;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 12,
        20,
        isDesktop ? 24 : 12,
        10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          ?extraAction,
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // BENTO GRID DASHBOARD WIDGET (12dp card border radius)
  // ----------------------------------------------------
  Widget _buildBentoGrid({
    required BuildContext context,
    required MusicPlayerController controller,
    required int likedCount,
    required int downloadedCount,
    required int historyCount,
    required int playlistCount,
    required Color accent,
    required ColorScheme colorScheme,
    required List<SongModel> speedDials,
  }) {
    return Column(
      children: <Widget>[
        // Top Row: Tall Liked Card + (Offline & History Stack)
        SizedBox(
          height: 160,
          child: Row(
            children: <Widget>[
              // Left: Liked Songs Hero Tall Card (12dp radius)
              Expanded(
                flex: 5,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 'Liked'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 160,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          accent.withValues(alpha: 0.16),
                          colorScheme.surfaceContainerHighest,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: accent.withValues(alpha: 0.65),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '$likedCount',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Liked songs',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Right: Stack of Offline & History Cards (12dp radius, 76dp each)
              Expanded(
                flex: 5,
                child: Column(
                  children: <Widget>[
                    // Offline Card
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 'Downloaded'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.offline_pin_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        'Offline',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        downloadedCount == 0 ? 'Downloaded' : '$downloadedCount songs',
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
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // History Card
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 'History'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.history_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        'History',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        historyCount == 0 ? 'Recent' : '$historyCount played',
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Bottom Row: Playlists & Top Tracks (12dp radius, 68dp each)
        SizedBox(
          height: 68,
          child: Row(
            children: <Widget>[
              // Playlists Card
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 'Playlists'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.queue_music_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Playlists',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$playlistCount created',
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
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Stats & Insights Card
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const StatsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.insights_rounded,
                              color: accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Stats',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Insights',
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // FEATURED "★ MOST PLAYED" HERO CARD (16dp radius, 10dp inner art)
  // ----------------------------------------------------
  Widget _buildFeaturedMostPlayedCard({
    required BuildContext context,
    required MusicPlayerController controller,
    required List<SongModel> speedDials,
    required List<SongModel> liked,
    required List<SongModel> history,
    required Color accent,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final featuredSong = speedDials.isNotEmpty
        ? speedDials.first
        : (history.isNotEmpty
            ? history.first
            : (liked.isNotEmpty ? liked.first : null));

    if (featuredSong == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.explore_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Explore Music',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Search & play tracks to populate your library',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.search_rounded, color: accent, size: 22),
              onPressed: widget.onSearchTapped,
            ),
          ],
        ),
      );
    }

    final queueToPlay = speedDials.isNotEmpty
        ? speedDials
        : (history.isNotEmpty ? history : liked);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Square Artwork (proportioned 104dp with 10dp radius for perfect alignment)
          M3EAlbumArt(
            imageUrl: featuredSong.thumbnailUrl,
            size: 104,
            radius: 10,
            elevation: 1,
          ),

          const SizedBox(width: 14),

          // Details & Action Buttons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '★ MOST PLAYED',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  featuredSong.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  featuredSong.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    M3EButton(
                      decoration: const M3EButtonDecoration(
                        haptic: M3EHapticFeedback.light,
                      ),
                      label: const Text('Play all'),
                      style: M3EButtonStyle.tonal,
                      size: M3EButtonSize.sm,
                      onPressed: () => controller.playSong(featuredSong, newQueue: queueToPlay),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: 18,
                          color: colorScheme.onSurface,
                        ),
                        tooltip: 'Shuffle',
                        onPressed: () {
                          controller.toggleShuffle();
                          controller.playSong(featuredSong, newQueue: queueToPlay);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // PLAYLISTS M3E LIST WIDGET (12dp outer, 4dp inner, 2dp gap)
  // ----------------------------------------------------
  Widget _buildPlaylistsM3EList({
    required BuildContext context,
    required MusicPlayerController controller,
    required dynamic playlists,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return M3EList(
      color: colorScheme.surfaceContainerHighest,
      outerRadius: 12,
      innerRadius: 4,
      gap: 2,
      haptic: M3EHapticFeedback.light,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          errorBuilder: (context, err, stack) => Icon(
                            Icons.queue_music_rounded,
                            color: colorScheme.onSurfaceVariant,
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
                        if (controller.isPlaylistFullyDownloaded(playlist.songs)) ...<Widget>[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.download_done_rounded,
                            size: 13,
                            color: controller.dynamicAccentColor,
                          ),
                        ] else if (controller.isPlaylistDownloading(playlist.songs)) ...<Widget>[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: controller.dynamicAccentColor,
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
                onPressed: () => controller.playPlaylist(playlist),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------------------------------
  // EMPTY PLAYLISTS PROMPT (12dp radius)
  // ----------------------------------------------------
  Widget _buildEmptyPlaylistsPrompt({
    required BuildContext context,
    required MusicPlayerController controller,
    required ColorScheme colorScheme,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.queue_music_rounded, color: colorScheme.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Create your first playlist',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Organize tracks into your personal mixes',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          M3EButton(
            decoration: const M3EButtonDecoration(
              haptic: M3EHapticFeedback.light,
            ),
            label: const Text('Create'),
            style: M3EButtonStyle.tonal,
            size: M3EButtonSize.sm,
            onPressed: () => _showCreatePlaylistDialog(context, controller),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CONFIRM REMOVE DOWNLOAD DIALOG
  // ----------------------------------------------------
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.delete_outline_rounded, color: accent, size: 28),
          title: Text(
            'Remove Download?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Text(
              'Remove "${song.title}" from offline storage? You can always download it again later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.removeDownload(song.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${song.title}" from offline music'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ----------------------------------------------------
  // CONFIRM CLEAR HISTORY DIALOG
  // ----------------------------------------------------
  void _confirmClearHistory(
    BuildContext context,
    MusicPlayerController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 28),
          title: Text(
            'Clear Playback History?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'This will clear your recent listening history.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                controller.clearHistory();
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------
  // CREATE PLAYLIST DIALOG
  // ----------------------------------------------------
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  borderRadius: BorderRadius.circular(10),
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
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
