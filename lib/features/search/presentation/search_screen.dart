import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:google_music/core/widgets/m3e_widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../models/song_model.dart';
import '../../player/presentation/now_playing_sheet.dart';

/// Search and discovery screen in Google Music.
class SearchScreen extends StatefulWidget {
  /// Creates search screen.
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  List<SongModel> _searchResults = <SongModel>[];
  bool _isSearching = false;
  bool _hasSearched = false;

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
    super.dispose();
  }

  /// Triggers debounced InnerTube search with a 2-second delay to ensure smooth phone typing.
  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = <SongModel>[];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _performSearch(trimmed);
    });
  }

  /// Immediately executes search when user submits keyboard or taps search.
  void _searchImmediately(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _performSearch(trimmed);
  }

  /// Dispatches search query to InnerTube API and updates state.
  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final controller = context.read<MusicPlayerController>();
    final results = await controller.innerTubeClient.search(query);

    if (mounted && _searchCtrl.text.trim() == query) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  /// Quick language selection search.
  void _selectLanguage(String language) {
    _searchCtrl.text = language;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults = <SongModel>[];
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
  }

  @override
  Widget build(BuildContext context) {
    final m3eTheme = M3ETheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = m3eTheme.colorScheme;
    final recentHistory = context.select<MusicPlayerController, List<SongModel>>(
      (c) => c.history,
    );
    final isDesktop = MediaQuery.sizeOf(context).width > 850;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 12,
                12,
                isDesktop ? 24 : 12,
                12,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
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
                          hintText: 'Search songs, artists, albums...',
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
                          Icons.mic_rounded,
                          size: 22,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const SearchScreenSkeleton()
                  : _hasSearched
                  ? _searchResults.isEmpty
                        ? Center(
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
                                  'Try searching for another song or artist',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
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
                                onTap: (int index) {
                                  M3ESongTile.handleTap(
                                    context,
                                    _searchResults[index],
                                    queue: _searchResults,
                                  );
                                  NowPlayingSheet.show(context);
                                },
                                itemBuilder: (BuildContext context, int index) {
                                  return M3ESongTile(
                                    song: _searchResults[index],
                                  );
                                },
                              ),
                            ],
                          )
                  : CustomScrollView(
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isDesktop ? 24 : 12,
                              12,
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
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
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
                                borderRadius: BorderRadius.circular(8),
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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              item.title,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
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
                        if (recentHistory.isNotEmpty) ...<Widget>[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                28,
                                12,
                                12,
                              ),
                              child: Text(
                                'Recent listens',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            sliver: SliverToBoxAdapter(
                              child: M3EList(
                                color: colorScheme.surfaceContainerHighest,
                                outerRadius: 12,
                                innerRadius: 4,
                                gap: 2,
                                itemCount: recentHistory.length.clamp(
                                  0,
                                  5,
                                ),
                                onTap: (int index) {
                                  M3ESongTile.handleTap(
                                    context,
                                    recentHistory[index],
                                    queue: recentHistory,
                                  );
                                  NowPlayingSheet.show(context);
                                },
                                itemBuilder: (BuildContext context, int index) {
                                  return M3ESongTile(
                                    song: recentHistory[index],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 150)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
