import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/update/app_update_service.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../models/song_model.dart';

/// Metadata definition for dynamic categorized home screen sections.
class _SectionHeaderData {
  /// Category eyebrow label (e.g. ROMANTIC & SOUL).
  final String label;

  /// Main section headline (e.g. Bollywood Romance).
  final String title;

  /// Creates section header data.
  const _SectionHeaderData(this.label, this.title);
}

/// Represents an immutable categorized card section on the home screen.
class _HomeSection {
  /// Header metadata (label and title).
  final _SectionHeaderData meta;

  /// Tracks belonging strictly to this section.
  final List<SongModel> tracks;

  /// Creates a home section.
  const _HomeSection({required this.meta, required this.tracks});
}

/// Primary Google Music Home Screen displaying moods, quick picks, trending carousels, and categorized music sections.
/// Features infinite scrolling, smart shuffle, and Instagram-style behavioral dwell time personalization.
class HomeScreen extends StatefulWidget {
  /// Callback when user taps search in the top bar.
  final VoidCallback onSearchTapped;

  /// Optional external scroll controller for coordinating navigation scroll-to-top.
  final ScrollController? scrollController;

  /// Creates home screen.
  const HomeScreen({
    super.key,
    required this.onSearchTapped,
    this.scrollController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _languages = const <String>[
    'Hindi',
    'English',
    'Punjabi',
    'Haryanvi',
  ];

  late final ScrollController _scrollController;
  String _selectedLanguage = 'Hindi';
  List<SongModel> _tracks = <SongModel>[];
  List<_HomeSection> _dynamicSections = <_HomeSection>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSmartShuffleActive = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isBeta =
            context.read<MusicPlayerController>().isBetaChannelEnabled;
        AppUpdateService.checkAndPrompt(
          context,
          manual: false,
          includeBeta: isBeta,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  /// Monitors scroll position to trigger infinite scroll pagination near the bottom.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 350) {
      _loadMoreTracks();
    }
  }

  /// Deduplicates tracks by ID and normalized title fingerprint so identical songs are never repeated.
  List<SongModel> _deduplicateTracks(List<SongModel> tracks) {
    final seenIds = <String>{};
    final seenFingerprints = <String>{};
    final List<SongModel> unique = <SongModel>[];

    for (final track in tracks) {
      if (seenIds.contains(track.id)) continue;
      final fp = SongModel.normalizeFingerprint(track.title);
      if (fp.isNotEmpty && seenFingerprints.contains(fp)) continue;

      seenIds.add(track.id);
      if (fp.isNotEmpty) {
        seenFingerprints.add(fp);
      }
      unique.add(track);
    }

    return unique;
  }

  /// Creates incremental categorized card sections from a slice of tracks.
  List<_HomeSection> _createSectionsFromTracks(
    List<SongModel> tracks, {
    int startIndex = 0,
    int startingSectionIndex = 0,
  }) {
    if (startIndex >= tracks.length) return <_HomeSection>[];
    final remaining = tracks.sublist(startIndex);
    final sections = <_HomeSection>[];
    int secIdx = startingSectionIndex;

    for (int i = 0; i < remaining.length; i += 5) {
      final chunk = remaining.sublist(i, min(i + 5, remaining.length));
      if (chunk.isEmpty) continue;
      final meta = _getSectionMeta(secIdx, chunk);
      sections.add(_HomeSection(meta: meta, tracks: chunk));
      secIdx++;
    }
    return sections;
  }

  /// Loads initial official hits for default language personalized to user taste.
  Future<void> _loadInitialData() async {
    final controller = context.read<MusicPlayerController>();
    controller.behaviorTracker.recordLanguageInteraction(_selectedLanguage);
    final tracks = await controller.innerTubeClient.getByLanguage(
      _selectedLanguage,
    );

    if (mounted) {
      final unique = _deduplicateTracks(tracks);
      final personalized = controller.getPersonalizedTracks(
        unique,
        language: _selectedLanguage,
      );
      setState(() {
        _tracks = personalized;
        _dynamicSections = _createSectionsFromTracks(
          personalized,
          startIndex: min(5, personalized.length),
          startingSectionIndex: 0,
        );
        _isLoading = false;
      });
    }
  }

  /// Loads next batch of songs when scrolling near bottom of screen.
  /// Appends exclusively new card sections at the bottom without mutating or reshuffling existing cards.
  Future<void> _loadMoreTracks() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _currentPage + 1;
    final controller = context.read<MusicPlayerController>();
    final newTracks = await controller.innerTubeClient.fetchMoreTracks(
      _selectedLanguage,
      nextPage,
    );

    if (mounted) {
      setState(() {
        if (newTracks.isNotEmpty) {
          _currentPage = nextPage;
          final existingIds = _tracks.map((s) => s.id).toSet();
          final existingFps = _tracks
              .map((s) => SongModel.normalizeFingerprint(s.title))
              .where((f) => f.isNotEmpty)
              .toSet();

          final uniqueNew = <SongModel>[];
          for (final track in newTracks) {
            if (existingIds.contains(track.id)) continue;
            final fp = SongModel.normalizeFingerprint(track.title);
            if (fp.isNotEmpty && existingFps.contains(fp)) continue;

            existingIds.add(track.id);
            if (fp.isNotEmpty) existingFps.add(fp);
            uniqueNew.add(track);
          }

          if (uniqueNew.isNotEmpty) {
            _tracks = <SongModel>[..._tracks, ...uniqueNew];
            final newSections = _createSectionsFromTracks(
              uniqueNew,
              startIndex: 0,
              startingSectionIndex: _dynamicSections.length,
            );
            _dynamicSections = <_HomeSection>[
              ..._dynamicSections,
              ...newSections,
            ];
          }
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    }
  }

  /// Filters songs according to selected language chip.
  Future<void> _onLanguageSelected(String lang) async {
    if (lang == _selectedLanguage &&
        _tracks.isNotEmpty &&
        !_isSmartShuffleActive) {
      return;
    }

    setState(() {
      _selectedLanguage = lang;
      _isLoading = true;
      _isSmartShuffleActive = false;
      _currentPage = 0;
      _hasMore = true;
      _tracks = <SongModel>[];
      _dynamicSections = <_HomeSection>[];
    });

    final controller = context.read<MusicPlayerController>();
    controller.behaviorTracker.recordLanguageInteraction(lang);
    final tracks = await controller.innerTubeClient.getByLanguage(lang);

    if (mounted && _selectedLanguage == lang) {
      final unique = _deduplicateTracks(tracks);
      final personalized = controller.getPersonalizedTracks(
        unique,
        language: lang,
      );
      setState(() {
        _tracks = personalized;
        _dynamicSections = _createSectionsFromTracks(
          personalized,
          startIndex: min(5, personalized.length),
          startingSectionIndex: 0,
        );
        _isLoading = false;
      });
    }
  }

  /// Shuffles and re-ranks songs on HomeScreen based on Instagram-style user behavior and dwell metrics.
  void _shuffleHomeScreenTracks() {
    if (_tracks.isEmpty) return;
    final controller = context.read<MusicPlayerController>();
    final shuffled = controller.smartShuffleTracks(
      _tracks,
      language: _selectedLanguage,
    );

    setState(() {
      _tracks = _deduplicateTracks(shuffled);
      _dynamicSections = _createSectionsFromTracks(
        _tracks,
        startIndex: min(5, _tracks.length),
        startingSectionIndex: 0,
      );
      _isSmartShuffleActive = true;
    });
  }

  /// Handler fetching fresh hits for the selected language.
  Future<void> _onRefresh() async {
    final controller = context.read<MusicPlayerController>();
    _currentPage = 0;
    _hasMore = true;
    if (_tracks.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }
    final freshTracks = await controller.innerTubeClient.getByLanguage(
      _selectedLanguage,
      forceRefresh: true,
    );

    if (mounted) {
      final unique = _deduplicateTracks(freshTracks);
      final personalized = _isSmartShuffleActive
          ? controller.smartShuffleTracks(unique, language: _selectedLanguage)
          : controller.getPersonalizedTracks(
              unique,
              language: _selectedLanguage,
            );
      setState(() {
        _tracks = personalized;
        _dynamicSections = _createSectionsFromTracks(
          personalized,
          startIndex: min(5, personalized.length),
          startingSectionIndex: 0,
        );
        _isLoading = false;
      });
    }
  }

  /// Generates contextual category titles and uppercase tags that authentically match the loaded tracks.
  _SectionHeaderData _getSectionMeta(int chunkIndex, List<SongModel> chunk) {
    /// Detect if a single dominant artist appears across 3 or more songs in this chunk.
    final Map<String, int> artistCounts = <String, int>{};
    for (final song in chunk) {
      final raw = song.artist
          .split(',')
          .first
          .split('•')
          .first
          .split('&')
          .first
          .split('|')
          .first
          .trim();
      if (raw.isNotEmpty &&
          !raw.toLowerCase().contains('music') &&
          !raw.toLowerCase().contains('series') &&
          !raw.toLowerCase().contains('records') &&
          !raw.toLowerCase().contains('vevo')) {
        artistCounts[raw] = (artistCounts[raw] ?? 0) + 1;
      }
    }

    for (final entry in artistCounts.entries) {
      if (entry.value >= 3) {
        return _SectionHeaderData('ARTIST SPOTLIGHT', 'Hits of ${entry.key}');
      }
    }

    final lang = _selectedLanguage.toLowerCase();
    if (lang == 'hindi') {
      const metas = <_SectionHeaderData>[
        _SectionHeaderData('RECOMMENDED', 'Recommended for you'),
        _SectionHeaderData('TOP BOLLYWOOD', 'Top Bollywood Hits'),
        _SectionHeaderData('CHARTBUSTERS', 'Trending Melodies'),
        _SectionHeaderData('POPULAR NOW', 'Popular in Hindi'),
        _SectionHeaderData('HIT MAKERS', 'Top Film Hits'),
        _SectionHeaderData('DISCOVER MORE', 'Hindi Chartbusters'),
      ];
      if (chunkIndex < metas.length) return metas[chunkIndex];
      return _SectionHeaderData(
        'MORE HITS',
        'Hindi Collection • Vol ${chunkIndex - metas.length + 2}',
      );
    } else if (lang == 'english') {
      const metas = <_SectionHeaderData>[
        _SectionHeaderData('RECOMMENDED', 'Recommended for you'),
        _SectionHeaderData('GLOBAL HITS', 'Top International Hits'),
        _SectionHeaderData('CHARTBUSTERS', 'Billboard Hits'),
        _SectionHeaderData('POPULAR NOW', 'Popular in English'),
        _SectionHeaderData('DISCOVER MORE', 'Trending Worldwide'),
      ];
      if (chunkIndex < metas.length) return metas[chunkIndex];
      return _SectionHeaderData(
        'MORE HITS',
        'English Collection • Vol ${chunkIndex - metas.length + 2}',
      );
    } else if (lang == 'punjabi') {
      const metas = <_SectionHeaderData>[
        _SectionHeaderData('RECOMMENDED', 'Recommended for you'),
        _SectionHeaderData('TOP PUNJABI', 'Punjabi Chartbusters'),
        _SectionHeaderData('POPULAR NOW', 'Top Punjabi Hits'),
        _SectionHeaderData('DESI HITS', 'Popular in Punjabi'),
        _SectionHeaderData('DISCOVER MORE', 'Trending Punjabi Tracks'),
      ];
      if (chunkIndex < metas.length) return metas[chunkIndex];
      return _SectionHeaderData(
        'MORE HITS',
        'Punjabi Collection • Vol ${chunkIndex - metas.length + 2}',
      );
    } else if (lang == 'haryanvi') {
      const metas = <_SectionHeaderData>[
        _SectionHeaderData('RECOMMENDED', 'Recommended for you'),
        _SectionHeaderData('TOP HARYANVI', 'Haryanvi Superhits'),
        _SectionHeaderData('POPULAR NOW', 'Top Desi Hits'),
        _SectionHeaderData('DESI BEATS', 'Trending in Haryanvi'),
      ];
      if (chunkIndex < metas.length) return metas[chunkIndex];
      return _SectionHeaderData(
        'MORE HITS',
        'Haryanvi Collection • Vol ${chunkIndex - metas.length + 2}',
      );
    } else {
      return _SectionHeaderData(
        'TOP HITS',
        'More $_selectedLanguage Hits • Vol ${chunkIndex + 1}',
      );
    }
  }

  /// Builds a section header widget with eyebrow tag, headline title, and optional action buttons.
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
        24,
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

  /// Builds a 5-item card list container styled with M3E rounded borders.
  Widget _buildCardList({
    required BuildContext context,
    required List<SongModel> tracks,
    required MusicPlayerController controller,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final isDesktop = MediaQuery.sizeOf(context).width > 850;

    Widget buildTile(SongModel track) {
      final playCount = controller.behaviorTracker.getPlayCount(track.id);
      final score = controller.behaviorTracker.computeTrackScore(
        track,
        targetLanguage: _selectedLanguage,
        addExplorationJitter: false,
      );
      final isPersonalPick = playCount >= 2 || score >= 28.0;
      final customSubtitle = playCount >= 2
          ? 'Most played • ${track.artist} • ${track.duration}'
          : null;

      return M3ESongTile(
        song: track,
        subtitle: customSubtitle,
        isPersonalPick: isPersonalPick,
      );
    }

    if (isDesktop && tracks.length >= 2) {
      final mid = (tracks.length + 1) ~/ 2;
      final leftTracks = tracks.sublist(0, mid);
      final rightTracks = tracks.sublist(mid);

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: M3EList(
                  color: colorScheme.surfaceContainerHighest,
                  outerRadius: 12,
                  innerRadius: 4,
                  gap: 2,
                  itemCount: leftTracks.length,
                  onTap: (int index) {
                    M3ESongTile.handleTap(
                      context,
                      leftTracks[index],
                      queue: tracks,
                    );
                  },
                  itemBuilder: (BuildContext context, int index) {
                    return buildTile(leftTracks[index]);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: M3EList(
                  color: colorScheme.surfaceContainerHighest,
                  outerRadius: 12,
                  innerRadius: 4,
                  gap: 2,
                  itemCount: rightTracks.length,
                  onTap: (int index) {
                    M3ESongTile.handleTap(
                      context,
                      rightTracks[index],
                      queue: tracks,
                    );
                  },
                  itemBuilder: (BuildContext context, int index) {
                    return buildTile(rightTracks[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverToBoxAdapter(
        child: M3EList(
          color: colorScheme.surfaceContainerHighest,
          outerRadius: 12,
          innerRadius: 4,
          gap: 2,
          itemCount: tracks.length,
          onTap: (int index) {
            M3ESongTile.handleTap(context, tracks[index], queue: tracks);
          },
          itemBuilder: (BuildContext context, int index) {
            return buildTile(tracks[index]);
          },
        ),
      ),
    );
  }

  /// Builds additional categorized card sections from the immutable appended sections list.
  List<Widget> _buildDynamicSections({
    required BuildContext context,
    required MusicPlayerController controller,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    if (_dynamicSections.isEmpty) return <Widget>[];

    final List<Widget> slivers = <Widget>[];
    for (final section in _dynamicSections) {
      slivers.add(
        SliverToBoxAdapter(
          child: _buildSectionHeader(
            context: context,
            label: section.meta.label,
            title: section.meta.title,
          ),
        ),
      );

      slivers.add(
        _buildCardList(
          context: context,
          tracks: section.tracks,
          controller: controller,
          colorScheme: colorScheme,
          theme: theme,
        ),
      );
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();
    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final speedDialTracks = controller.getSpeedDialSongs(
      limit: 5,
      fallbackTracks: _tracks,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            floating: true,
            pinned: false,
            titleSpacing: isDesktop ? 24 : 12,
            backgroundColor: colorScheme.surface,
            elevation: 0,
            title: Row(
              children: <Widget>[
                Text(
                  'Google Music',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
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
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 12,
                ),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: M3EChip(
                      label: _isSmartShuffleActive
                          ? 'Smart Mix'
                          : 'Shuffle Feed',
                      type: M3EChipType.filter,
                      selected: _isSmartShuffleActive,
                      onPressed: _shuffleHomeScreenTracks,
                    ),
                  ),
                  ..._languages.map((lang) {
                    final isSelected =
                        lang == _selectedLanguage && !_isSmartShuffleActive;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: M3EChip(
                        label: lang,
                        type: M3EChipType.filter,
                        selected: isSelected,
                        onPressed: () => _onLanguageSelected(lang),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          if (_isLoading) ...<Widget>[
            const SliverToBoxAdapter(child: HomeScreenSkeleton()),
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ] else if (_tracks.isEmpty) ...<Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.music_off_rounded,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No songs found',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap reload to fetch fresh live tracks from Google Music.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      M3EButton(
                        label: const Text('Reload'),
                        style: M3EButtonStyle.tonal,
                        onPressed: () => _onRefresh(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...<Widget>[
            if (_tracks.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context: context,
                  label: _isSmartShuffleActive
                      ? 'BASED ON YOUR TASTE'
                      : (controller.history.isNotEmpty ||
                            controller.likedSongs.isNotEmpty)
                      ? 'FOR YOU'
                      : 'SPEED DIAL',
                  title:
                      (controller.history.isNotEmpty ||
                          controller.likedSongs.isNotEmpty)
                      ? 'Listen again'
                      : 'Speed dials',
                  extraAction: M3EButton(
                    label: const Text('Play all'),
                    style: M3EButtonStyle.tonal,
                    size: M3EButtonSize.sm,
                    onPressed: () {
                      if (speedDialTracks.isNotEmpty) {
                        controller.playSong(
                          speedDialTracks.first,
                          newQueue: speedDialTracks,
                        );
                      }
                    },
                  ),
                ),
              ),
              _buildCardList(
                context: context,
                tracks: speedDialTracks,
                controller: controller,
                colorScheme: colorScheme,
                theme: theme,
              ),
            ],
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context: context,
                label: 'POPULAR CHARTS',
                title: 'Trending in $_selectedLanguage',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Builder(
                  builder: (context) {
                    final speedDialIds = speedDialTracks
                        .map((s) => s.id)
                        .toSet();
                    final speedDialFps = speedDialTracks
                        .map((s) => SongModel.normalizeFingerprint(s.title))
                        .where((f) => f.isNotEmpty)
                        .toSet();

                    final carouselTracks = _tracks
                        .where((t) {
                          if (speedDialIds.contains(t.id)) return false;
                          final fp = SongModel.normalizeFingerprint(t.title);
                          if (fp.isNotEmpty && speedDialFps.contains(fp)) {
                            return false;
                          }
                          return true;
                        })
                        .take(10)
                        .toList();

                    final displayTracks = carouselTracks.isNotEmpty
                        ? carouselTracks
                        : _tracks.take(10).toList();

                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 12,
                      ),
                      itemCount: displayTracks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final song = displayTracks[index];
                        return GestureDetector(
                          onTap: () {
                            controller.playSong(song, newQueue: _tracks);
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
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            ..._buildDynamicSections(
              context: context,
              controller: controller,
              colorScheme: colorScheme,
              theme: theme,
            ),
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: controller.dynamicAccentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading more songs for you...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ],
      ),
    );
  }
}
