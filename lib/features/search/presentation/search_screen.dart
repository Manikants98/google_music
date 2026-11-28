import 'dart:async';

import 'package:google_music/core/widgets/m3e_widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../models/playlist_model.dart';
import '../../../models/song_model.dart';
import '../../player/presentation/now_playing_sheet.dart';
import '../../playlist/presentation/playlist_detail_screen.dart';

/// Active search tab filter for partitioned discovery.
enum SearchTab { all, songs, playlists }

/// Search and discovery screen in Google Music supporting songs, playlists,
/// auto-complete, recent searches, and instant playback queue generation.
class SearchScreen extends StatefulWidget {
  /// Creates search screen.
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  List<SongModel> _searchResults = <SongModel>[];
  List<PlaylistModel> _playlistResults = <PlaylistModel>[];
  bool _isSearching = false;
  bool _hasSearched = false;
  SearchTab _selectedTab = SearchTab.all;

  final List<({String title, String subtitle, Color color, IconData icon})>
  _languages =
      const <({String title, String subtitle, Color color, IconData icon})>[
        (
          title: 'Hindi',
          subtitle: 'Bollywood & Indies',
          color: Color(0xFFE53935),
          icon: Icons.music_note_rounded,
        ),
        (
          title: 'English',
          subtitle: 'Billboard & Pop',
          color: Color(0xFF1E88E5),
          icon: Icons.language_rounded,
        ),
        (
          title: 'Punjabi',
          subtitle: 'Bhangra & Pop Hits',
          color: Color(0xFFFB8C00),
          icon: Icons.graphic_eq_rounded,
        ),
        (
          title: 'Haryanvi',
          subtitle: 'Desi Ragni & Hits',
          color: Color(0xFF43A047),
          icon: Icons.speaker_group_rounded,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Triggers debounced search with a fast 400ms delay for fluid responsiveness.
  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = <SongModel>[];
        _playlistResults = <PlaylistModel>[];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(trimmed);
    });
  }

  /// Immediately executes search when user submits keyboard or taps a query chip.
  void _searchImmediately(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _performSearch(trimmed);
  }

  /// Dispatches search query to InnerTube API fetching songs and playlists in parallel.
  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final controller = context.read<MusicPlayerController>();

    final songFuture = controller.innerTubeClient.search(query);
    final playlistFuture = controller.innerTubeClient.searchPlaylists(query);

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      songFuture,
      playlistFuture,
    ]);

    if (mounted && _searchCtrl.text.trim() == query) {
      setState(() {
        _searchResults = results[0] as List<SongModel>;
        _playlistResults = results[1] as List<PlaylistModel>;
        _isSearching = false;
      });
    }
  }

  /// Tapping a song starts playback seeded with watch-next recommendations
  /// and automatically clears the search field and resets state.
  void _onSongTapped(SongModel song) {
    final controller = context.read<MusicPlayerController>();
    controller.playSongFromSearch(song);
    NowPlayingSheet.show(context);

    // Clear search field so stale search word/results don't linger on back navigation
    _searchCtrl.clear();
    _focusNode.unfocus();
    setState(() {
      _searchResults = <SongModel>[];
      _playlistResults = <PlaylistModel>[];
      _hasSearched = false;
      _isSearching = false;
    });
  }

  /// Tapping a playlist navigates to the playlist detail view.
  void _onPlaylistTapped(PlaylistModel playlist) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailScreen(
          playlistId: playlist.id,
          initialPlaylist: playlist,
        ),
      ),
    );
  }

  /// Quick language selection search.
  void _selectLanguage(String language) {
    _searchCtrl.text = language;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults = <SongModel>[];
      _playlistResults = <PlaylistModel>[];
    });

    final controller = context.read<MusicPlayerController>();
    controller.innerTubeClient.getByLanguage(language).then((results) {
      if (mounted && _searchCtrl.text == language) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });

    controller.innerTubeClient.searchPlaylists(language).then((pResults) {
      if (mounted && _searchCtrl.text == language) {
        setState(() {
          _playlistResults = pResults;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m3eTheme = M3ETheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = m3eTheme.colorScheme;
    final accent = context.select<MusicPlayerController, Color>(
      (c) => c.dynamicAccentColor,
    );
    final recentSearches =
        context.select<MusicPlayerController, List<SongModel>>(
      (c) => c.recentSearches,
    );
    final isDesktop = MediaQuery.sizeOf(context).width > 850;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Search Input Field
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 12,
                12,
                isDesktop ? 24 : 12,
                8,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(width: 14),
                    Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        onChanged: _onQueryChanged,
                        onSubmitted: _searchImmediately,
                        textInputAction: TextInputAction.search,
                        textAlignVertical: TextAlignVertical.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          hintText: 'Search songs, artists, playlists...',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        color: colorScheme.onSurfaceVariant,
                        splashRadius: 20,
                        onPressed: () {
                          _searchCtrl.clear();
                          _onQueryChanged('');
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            // Filter Tabs (All / Songs / Playlists)
            if (_hasSearched || _searchCtrl.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 12,
                  2,
                  isDesktop ? 24 : 12,
                  8,
                ),
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: <Widget>[
                      _buildFilterChip('All', SearchTab.all, accent, colorScheme),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Songs (${_searchResults.length})',
                        SearchTab.songs,
                        accent,
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Playlists (${_playlistResults.length})',
                        SearchTab.playlists,
                        accent,
                        colorScheme,
                      ),
                    ],
                  ),
                ),
              ),

            // Main Content Area
            Expanded(
              child: _isSearching
                  ? const SearchScreenSkeleton()
                  : _hasSearched
                      ? _buildSearchResults(context, theme, colorScheme, accent, isDesktop)
                      : _buildDefaultDiscovery(
                          context,
                          theme,
                          colorScheme,
                          accent,
                          recentSearches,
                          isDesktop,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    SearchTab tab,
    Color accent,
    M3EColorScheme colorScheme,
  ) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accent
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? (accent.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                  : colorScheme.onSurface,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    ThemeData theme,
    M3EColorScheme colorScheme,
    Color accent,
    bool isDesktop,
  ) {
    final hasNoResults = _searchResults.isEmpty && _playlistResults.isEmpty;

    if (hasNoResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.music_off_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching for another song, artist, or playlist',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    switch (_selectedTab) {
      case SearchTab.songs:
        return _buildSongsList(context, colorScheme, isDesktop);

      case SearchTab.playlists:
        return _buildPlaylistsGrid(context, theme, colorScheme, isDesktop);

      case SearchTab.all:
        return ListView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 12,
            0,
            isDesktop ? 24 : 12,
            120,
          ),
          children: <Widget>[
            // Top Songs Section
            if (_searchResults.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Songs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_searchResults.length > 5)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = SearchTab.songs;
                          });
                        },
                        child: Text(
                          'See all',
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              M3EList(
                color: colorScheme.surfaceContainerHighest,
                outerRadius: 12,
                innerRadius: 4,
                gap: 2,
                itemCount: _searchResults.length.clamp(0, 5),
                onTap: (int index) => _onSongTapped(_searchResults[index]),
                itemBuilder: (BuildContext context, int index) {
                  return M3ESongTile(
                    song: _searchResults[index],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Playlists Section (Carousel)
            if (_playlistResults.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Playlists',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_playlistResults.length > 4)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = SearchTab.playlists;
                          });
                        },
                        child: Text(
                          'See all',
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 195,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _playlistResults.length.clamp(0, 8),
                  separatorBuilder: (_, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final playlist = _playlistResults[index];
                    return _buildPlaylistCard(
                      context,
                      playlist,
                      theme,
                      colorScheme,
                      135,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Additional Songs if any
            if (_searchResults.length > 5) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'More Songs',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              M3EList(
                color: colorScheme.surfaceContainerHighest,
                outerRadius: 12,
                innerRadius: 4,
                gap: 2,
                itemCount: _searchResults.length - 5,
                onTap: (int index) => _onSongTapped(_searchResults[index + 5]),
                itemBuilder: (BuildContext context, int index) {
                  return M3ESongTile(
                    song: _searchResults[index + 5],
                  );
                },
              ),
            ],
          ],
        );
    }
  }

  Widget _buildSongsList(
    BuildContext context,
    M3EColorScheme colorScheme,
    bool isDesktop,
  ) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No songs found for this search',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 12,
        0,
        isDesktop ? 24 : 12,
        120,
      ),
      children: <Widget>[
        M3EList(
          color: colorScheme.surfaceContainerHighest,
          outerRadius: 12,
          innerRadius: 4,
          gap: 2,
          itemCount: _searchResults.length,
          onTap: (int index) => _onSongTapped(_searchResults[index]),
          itemBuilder: (BuildContext context, int index) {
            return M3ESongTile(
              song: _searchResults[index],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaylistsGrid(
    BuildContext context,
    ThemeData theme,
    M3EColorScheme colorScheme,
    bool isDesktop,
  ) {
    if (_playlistResults.isEmpty) {
      return Center(
        child: Text(
          'No playlists found for this search',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 12,
        8,
        isDesktop ? 24 : 12,
        120,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _playlistResults.length,
      itemBuilder: (context, index) {
        return _buildPlaylistCard(
          context,
          _playlistResults[index],
          theme,
          colorScheme,
          double.infinity,
        );
      },
    );
  }

  Widget _buildPlaylistCard(
    BuildContext context,
    PlaylistModel playlist,
    ThemeData theme,
    M3EColorScheme colorScheme,
    double width,
  ) {
    return GestureDetector(
      onTap: () => _onPlaylistTapped(playlist),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: playlist.thumbnailUrl != null &&
                        playlist.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        playlist.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.queue_music_rounded,
                            size: 40,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.queue_music_rounded,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (playlist.author != null && playlist.author!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                playlist.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultDiscovery(
    BuildContext context,
    ThemeData theme,
    M3EColorScheme colorScheme,
    Color accent,
    List<SongModel> recentSearches,
    bool isDesktop,
  ) {
    final controller = context.read<MusicPlayerController>();

    return CustomScrollView(
      slivers: <Widget>[
        // Recent Searches Section
        if (recentSearches.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 12,
                8,
                isDesktop ? 24 : 12,
                8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Recent searches',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: controller.clearRecentSearches,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12),
            sliver: SliverToBoxAdapter(
              child: M3EList(
                color: colorScheme.surfaceContainerHighest,
                outerRadius: 12,
                innerRadius: 4,
                gap: 2,
                itemCount: recentSearches.length.clamp(0, 6),
                onTap: (int index) => _onSongTapped(recentSearches[index]),
                itemBuilder: (BuildContext context, int index) {
                  final song = recentSearches[index];
                  return M3ESongTile(
                    song: song,
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: colorScheme.onSurfaceVariant,
                      tooltip: 'Remove from history',
                      onPressed: () =>
                          controller.removeFromRecentSearches(song.id),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // Browse By Language Section
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 12,
              8,
              isDesktop ? 24 : 12,
              12,
            ),
            child: Text(
              'Browse by language',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 12,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: isDesktop ? 2.5 : 2,
            ),
            delegate: SliverChildBuilderDelegate((
              context,
              index,
            ) {
              final item = _languages[index];
              return InkWell(
                onTap: () => _selectLanguage(item.title),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        item.color.withValues(alpha: 0.85),
                        item.color.withValues(alpha: 0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              item.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        item.icon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: _languages.length),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 150)),
      ],
    );
  }
}
