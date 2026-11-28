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
  String _activeTab = 'Library';

  final List<_LibraryTabItem> _tabs = const <_LibraryTabItem>[
    _LibraryTabItem(id: 'Library', label: 'Library', icon: Icons.graphic_eq_rounded),
    _LibraryTabItem(id: 'Playlists', label: 'Playlists', icon: Icons.queue_music_rounded),
    _LibraryTabItem(id: 'Liked', label: 'Liked', icon: Icons.favorite_rounded),
    _LibraryTabItem(id: 'Downloaded', label: 'Downloaded', icon: Icons.offline_pin_rounded),
    _LibraryTabItem(id: 'History', label: 'History', icon: Icons.history_rounded),
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
    final hPad = isDesktop ? 24.0 : 16.0;
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
          // Filter Chips Carousel
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                itemCount: _tabs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isSelected = tab.id == _activeTab;
                  return _buildFilterChip(
                    context: context,
                    tab: tab,
                    isSelected: isSelected,
                    accent: accent,
                    onTap: () {
                      setState(() {
                        _activeTab = tab.id;
                      });
                    },
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // ----------------------------------------------------
          // MAIN DASHBOARD (When 'Library' tab is active)
          // ----------------------------------------------------
          if (_activeTab == 'Library') ...<Widget>[
            // Bento Grid Cards
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

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // Featured / Most Played Banner Card
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
                ),
              ),
            ),

            // Recently Played Section (Horizontal Carousel)
            if (history.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Recently Played',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _activeTab = 'History'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 172,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    itemCount: history.take(12).length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final song = history[index];
                      return _buildRecentSongCard(
                        context: context,
                        song: song,
                        queue: history,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                ),
              ),
            ],

            // Playlists Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Your Playlists',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showCreatePlaylistDialog(context, controller),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.add_rounded, size: 15, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              'New',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent,
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'All Playlists (${playlists.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _showCreatePlaylistDialog(context, controller),
                    ),
                  ],
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
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No playlists yet',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create custom playlists like "Gym Vibes" or "Chill Beats"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Playlist'),
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Liked Songs (${liked.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (liked.isNotEmpty)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        onPressed: () => controller.playSong(liked.first, newQueue: liked),
                      ),
                  ],
                ),
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
                        size: 64,
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Offline Music (${downloaded.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        controller.offlineService.formattedStorageUsed,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
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
                        size: 64,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No downloaded music',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Download songs for offline listening from the track menu',
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Playback History (${history.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (history.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () => _confirmClearHistory(context, controller),
                      ),
                  ],
                ),
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
                        size: 64,
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
  // FILTER CHIP WIDGET
  // ----------------------------------------------------
  Widget _buildFilterChip({
    required BuildContext context,
    required _LibraryTabItem tab,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final fgColor = isSelected
        ? (accent.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        : colorScheme.onSurface;
    final bgColor = isSelected ? accent : colorScheme.surfaceContainerHighest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(tab.icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // BENTO GRID DASHBOARD WIDGET
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
          height: 172,
          child: Row(
            children: <Widget>[
              // Left: Liked Songs Hero Tall Card
              Expanded(
                flex: 5,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 'Liked'),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 172,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          accent.withValues(alpha: 0.18),
                          colorScheme.surfaceContainerHighest,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: accent,
                                    size: 24,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: accent.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '$likedCount',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Liked songs',
                            style: TextStyle(
                              fontSize: 14,
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

              const SizedBox(width: 10),

              // Right: Stack of Offline & History Cards
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
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.offline_pin_rounded,
                                    color: accent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        'Offline',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        downloadedCount == 0 ? 'Downloaded' : '$downloadedCount songs',
                                        style: TextStyle(
                                          fontSize: 12,
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

                    const SizedBox(height: 10),

                    // History Card
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 'History'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.history_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        'History',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        historyCount == 0 ? 'Recent' : '$historyCount played',
                                        style: TextStyle(
                                          fontSize: 12,
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

        const SizedBox(height: 10),

        // Bottom Row: Playlists & Top Tracks
        SizedBox(
          height: 76,
          child: Row(
            children: <Widget>[
              // Playlists Card
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 'Playlists'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.queue_music_rounded,
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
                                  'Playlists',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$playlistCount created',
                                  style: TextStyle(
                                    fontSize: 12,
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

              const SizedBox(width: 10),

              // Top Tracks / Speed Dial Card
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (speedDials.isNotEmpty) {
                        controller.playSong(speedDials.first, newQueue: speedDials);
                      } else if (controller.history.isNotEmpty) {
                        controller.playSong(controller.history.first, newQueue: controller.history);
                      } else if (controller.likedSongs.isNotEmpty) {
                        controller.playSong(controller.likedSongs.first, newQueue: controller.likedSongs);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.trending_up_rounded,
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
                                  'Top Tracks',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Speed Dials',
                                  style: TextStyle(
                                    fontSize: 12,
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
  // FEATURED "★ MOST PLAYED" HERO CARD
  // ----------------------------------------------------
  Widget _buildFeaturedMostPlayedCard({
    required BuildContext context,
    required MusicPlayerController controller,
    required List<SongModel> speedDials,
    required List<SongModel> liked,
    required List<SongModel> history,
    required Color accent,
    required ColorScheme colorScheme,
  }) {
    final featuredSong = speedDials.isNotEmpty
        ? speedDials.first
        : (history.isNotEmpty
            ? history.first
            : (liked.isNotEmpty ? liked.first : null));

    if (featuredSong == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.explore_rounded, color: accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Explore & Play Music',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Search for your favorite tracks to populate your library',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.search_rounded, color: accent),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          // Square Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 90,
              height: 90,
              child: featuredSong.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      featuredSong.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, err, stack) => Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                      ),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHigh,
                      child: Icon(
                        Icons.music_note_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    ),
            ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '★ MOST PLAYED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  featuredSong.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  featuredSong.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Play all',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => controller.playSong(featuredSong, newQueue: queueToPlay),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: 17,
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
  // RECENT SONG HORIZONTAL CARD
  // ----------------------------------------------------
  Widget _buildRecentSongCard({
    required BuildContext context,
    required SongModel song,
    required List<SongModel> queue,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: 110,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => M3ESongTile.handleTap(context, song, queue: queue),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: song.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          song.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, err, stack) => Container(
                            color: colorScheme.surfaceContainerHigh,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PLAYLISTS M3E LIST WIDGET
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: playlist.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
  // EMPTY PLAYLISTS PROMPT
  // ----------------------------------------------------
  Widget _buildEmptyPlaylistsPrompt({
    required BuildContext context,
    required MusicPlayerController controller,
    required ColorScheme colorScheme,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.queue_music_rounded, color: colorScheme.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 14),
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => _showCreatePlaylistDialog(context, controller),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  borderRadius: BorderRadius.circular(14),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

class _LibraryTabItem {
  final String id;
  final String label;
  final IconData icon;

  const _LibraryTabItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}
