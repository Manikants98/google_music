import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/network/lyrics_service.dart';
import '../../../core/widgets/m3e_widgets.dart';
import '../../../models/song_model.dart';

/// Modal bottom sheet presenting dynamic tabs for Up Next queue, synchronized Lyrics, and Related recommendations.
class QueueBottomSheet extends StatefulWidget {
  /// The initially selected tab index (0: UP NEXT, 1: LYRICS, 2: RELATED).
  final int initialTab;

  /// Creates a player details bottom sheet.
  const QueueBottomSheet({super.key, this.initialTab = 0});

  @override
  State<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends State<QueueBottomSheet> {
  late int _activeTab;
  late final ScrollController _queueScrollController;
  late final ScrollController _lyricsScrollController;

  /// Cached future for lyrics fetching.
  Future<LyricsData?>? _lyricsFuture;

  /// Cached future for related tracks fetching.
  Future<Map<String, List<SongModel>>>? _relatedFuture;

  /// Track ID associated with current futures to prevent redundant refetches.
  String? _cachedSongId;

  /// Last active synced lyric line index to avoid unnecessary auto-scroll triggering.
  int _lastSyncedIndex = -1;

  /// Indicates whether the user is manually inspecting lyrics so auto-scroll pauses.
  bool _userIsScrollingLyrics = false;

  /// Timer to resume auto-scrolling lyrics after manual user interaction ceases.
  Timer? _lyricsScrollResumeTimer;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _queueScrollController = ScrollController();
    _lyricsScrollController = ScrollController();
    _queueScrollController.addListener(_onQueueScroll);

    /// Eagerly ensure plenty of similar tracks when the queue sheet is opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = context.read<MusicPlayerController>();
        final remaining = controller.queue.length - 1 - controller.currentIndex;
        if (remaining <= 4) {
          controller.ensureAutoplayQueue(force: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _lyricsScrollResumeTimer?.cancel();
    _queueScrollController.removeListener(_onQueueScroll);
    _queueScrollController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  /// Monitors scroll position to fetch more similar songs continuously when user scrolls down.
  void _onQueueScroll() {
    if (!_queueScrollController.hasClients) return;
    final maxScroll = _queueScrollController.position.maxScrollExtent;
    final currentScroll = _queueScrollController.position.pixels;
    if (currentScroll >= maxScroll - 250) {
      final controller = context.read<MusicPlayerController>();
      if (!controller.isFetchingAutoplay) {
        controller.ensureAutoplayQueue(force: true);
      }
    }
  }

  /// Ensures lyrics and related data futures are initialized for the current song.
  void _ensureDataLoaded(MusicPlayerController controller, SongModel? song) {
    if (song == null) return;
    if (_cachedSongId != song.id) {
      _cachedSongId = song.id;
      _lastSyncedIndex = -1;
      _userIsScrollingLyrics = false;
      _lyricsFuture = controller.lyricsService.getLyrics(song);
      _relatedFuture = _fetchRelatedData(controller, song);
    }
  }

  /// Fetches both watch-next recommendations and artist catalog in parallel.
  Future<Map<String, List<SongModel>>> _fetchRelatedData(
    MusicPlayerController controller,
    SongModel song,
  ) async {
    final cleanArtist = SongModel.sanitizeArtist(song.artist);

    final results = await Future.wait<List<SongModel>>(
      <Future<List<SongModel>>>[
        controller.innerTubeClient.getWatchNextRecommendations(song.id),
        cleanArtist.isNotEmpty
            ? controller.innerTubeClient.search('$cleanArtist songs')
            : Future<List<SongModel>>.value(<SongModel>[]),
      ],
    );

    return <String, List<SongModel>>{
      'recommendations': results[0],
      'artistSongs': results[1],
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicPlayerController>();
    final currentSong = controller.currentSong;
    _ensureDataLoaded(controller, currentSong);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E2E2E)
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    _buildTabButton(0, 'UP NEXT', theme, controller),
                    _buildTabButton(1, 'LYRICS', theme, controller),
                    _buildTabButton(2, 'RELATED', theme, controller),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: <Widget>[
                  _buildQueueTab(context, controller, theme, colorScheme),
                  _buildLyricsTab(
                    context,
                    controller,
                    theme,
                    colorScheme,
                    currentSong,
                  ),
                  _buildRelatedTab(
                    context,
                    controller,
                    theme,
                    colorScheme,
                    currentSong,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a pill tab button in the header.
  Widget _buildTabButton(
    int index,
    String label,
    ThemeData theme,
    MusicPlayerController controller,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? controller.dynamicAccentColor.withValues(
                    alpha: isDark ? 0.22 : 0.15,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 1.1,
              color: isSelected
                  ? (isDark ? Colors.white : theme.colorScheme.primary)
                  : (isDark
                        ? Colors.white60
                        : theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the Up Next queue tab content.
  Widget _buildQueueTab(
    BuildContext context,
    MusicPlayerController controller,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final queue = controller.queue;
    final currentIndex = controller.currentIndex;

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Playing Queue',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Similar songs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: _queueScrollController,
            padding: const EdgeInsets.symmetric(vertical: 4),
            buildDefaultDragHandles: false,
            itemCount: queue.length,
            onReorderItem: controller.reorderQueue,
            footer: controller.isFetchingAutoplay
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
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
                            'Loading more similar songs...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final song = queue[index];
              final isCurrent = index == currentIndex;
              final isPlaying = isCurrent && controller.isPlaying;
              final isDark = theme.brightness == Brightness.dark;
              final activeAccent = controller.getLegibleAccentColor(isDark);

              return Material(
                key: ObjectKey(song),
                color: isCurrent
                    ? activeAccent.withValues(alpha: 0.12)
                    : Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            controller.playSong(song);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: <Widget>[
                                Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    M3EAlbumArt(
                                      imageUrl: song.thumbnailUrl,
                                      size: 42,
                                      radius: 4,
                                    ),
                                    if (isPlaying)
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.45,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Center(
                                          child: M3EWaveformBars(
                                            color: activeAccent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      isCurrent
                                          ? M3EMarqueeText(
                                              text: song.title,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
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
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    letterSpacing: -0.1,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                            ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${song.artist} • ${song.duration}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 12,
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
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Remove',
                        color: colorScheme.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          controller.removeFromQueue(index);
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            size: 22,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Builds the dynamic Lyrics tab with synchronized karaoke scrolling and tap-to-seek.
  Widget _buildLyricsTab(
    BuildContext context,
    MusicPlayerController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    SongModel? song,
  ) {
    if (song == null) {
      return Center(
        child: Text(
          'No song currently playing',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return FutureBuilder<LyricsData?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: controller.dynamicAccentColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Searching lyrics...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final lyrics = snapshot.data;
        if (lyrics == null ||
            (!lyrics.hasSyncedLyrics &&
                (lyrics.plainLyrics == null ||
                    lyrics.plainLyrics!.trim().isEmpty))) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.lyrics_outlined,
                    size: 54,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Lyrics not available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We couldn\'t find lyrics for "${song.title}".',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    onPressed: () {
                      setState(() {
                        _cachedSongId = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }

        /// If synchronized lyrics are available, render interactive karaoke list.
        if (lyrics.hasSyncedLyrics) {
          final position = controller.position;
          int activeIndex = -1;
          for (int i = 0; i < lyrics.syncedLines.length; i++) {
            if (lyrics.syncedLines[i].timestamp <= position) {
              activeIndex = i;
            } else {
              break;
            }
          }

          if (!_userIsScrollingLyrics &&
              activeIndex != _lastSyncedIndex &&
              activeIndex >= 0) {
            _lastSyncedIndex = activeIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_lyricsScrollController.hasClients) {
                final targetOffset = (activeIndex * 58.0) - 160.0;
                final clamped = targetOffset.clamp(
                  0.0,
                  _lyricsScrollController.position.maxScrollExtent,
                );
                _lyricsScrollController.animateTo(
                  clamped,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }

          return Stack(
            children: <Widget>[
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification) {
                    if (notification.direction != ScrollDirection.idle) {
                      _userIsScrollingLyrics = true;
                      _lyricsScrollResumeTimer?.cancel();
                    } else {
                      _lyricsScrollResumeTimer?.cancel();
                      _lyricsScrollResumeTimer = Timer(
                        const Duration(seconds: 4),
                        () {
                          if (mounted) {
                            setState(() {
                              _userIsScrollingLyrics = false;
                            });
                          }
                        },
                      );
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _lyricsScrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  itemCount: lyrics.syncedLines.length + 1,
                  itemBuilder: (context, index) {
                    if (index == lyrics.syncedLines.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40, bottom: 28),
                        child: Center(
                          child: Text(
                            'Lyrics provided by ${lyrics.source}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }

                    final line = lyrics.syncedLines[index];
                    final isActive = index == activeIndex;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _userIsScrollingLyrics = false;
                        });
                        controller.seek(line.timestamp);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                            fontSize: isActive ? 22 : 17,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isActive
                                ? (theme.brightness == Brightness.dark
                                      ? Colors.white
                                      : colorScheme.onSurface)
                                : colorScheme.onSurfaceVariant.withValues(
                                    alpha: line.isInstrumental ? 0.25 : 0.45,
                                  ),
                            letterSpacing: line.isInstrumental ? 4.0 : 0.0,
                            height: 1.45,
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(line.text, textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_userIsScrollingLyrics && activeIndex >= 0)
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        _userIsScrollingLyrics = false;
                      });
                      if (_lyricsScrollController.hasClients) {
                        final targetOffset = (activeIndex * 58.0) - 160.0;
                        final clamped = targetOffset.clamp(
                          0.0,
                          _lyricsScrollController.position.maxScrollExtent,
                        );
                        _lyricsScrollController.animateTo(
                          clamped,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    backgroundColor: theme.brightness == Brightness.dark
                        ? const Color(0xFF2C2C2C)
                        : colorScheme.surfaceContainerHighest,
                    icon: Icon(
                      Icons.sync_rounded,
                      size: 18,
                      color: controller.dynamicAccentColor,
                    ),
                    label: Text(
                      'Sync',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        /// Plain text lyrics fallback (e.g. YouTube Music official lyrics).
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SelectableText(
                  lyrics.plainLyrics!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    height: 1.85,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 36),
                Center(
                  child: Text(
                    'Lyrics provided by ${lyrics.source}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      fontSize: 11,
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

  /// Builds the dynamic Related tab with YouTube recommendations, artist hits, and audio info.
  Widget _buildRelatedTab(
    BuildContext context,
    MusicPlayerController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    SongModel? song,
  ) {
    if (song == null) {
      return Center(
        child: Text(
          'No song currently playing',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, List<SongModel>>>(
      future: _relatedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: controller.dynamicAccentColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Discovering related tracks...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data;
        final recommendations = data?['recommendations'] ?? <SongModel>[];
        final artistSongs = data?['artistSongs'] ?? <SongModel>[];

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: <Widget>[
            /// Section 1: You Might Also Like (YouTube algorithm recommendations).
            if (recommendations.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Row(
                  children: <Widget>[
                    Text(
                      'You might also like',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              ...recommendations.take(6).map((recSong) {
                return _buildRelatedSongTile(
                  recSong,
                  controller,
                  theme,
                  colorScheme,
                );
              }),
              const SizedBox(height: 16),
            ],

            /// Section 2: More from Artist.
            if (artistSongs.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'More from ${SongModel.sanitizeArtist(song.artist)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...artistSongs.take(6).map((artSong) {
                return _buildRelatedSongTile(
                  artSong,
                  controller,
                  theme,
                  colorScheme,
                );
              }),
              const SizedBox(height: 16),
            ],

            /// Section 3: About this song / Audio stream info card.
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1B1B1B)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C)
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'About this track',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTrackMetaRow('Title', song.title, theme, colorScheme),
                  const SizedBox(height: 6),
                  _buildTrackMetaRow('Artist', song.artist, theme, colorScheme),
                  const SizedBox(height: 6),
                  _buildTrackMetaRow(
                    'Duration',
                    song.duration,
                    theme,
                    colorScheme,
                  ),
                  const SizedBox(height: 6),
                  _buildTrackMetaRow(
                    'Audio Quality',
                    'High Bitrate 320 kbps (Direct)',
                    theme,
                    colorScheme,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds a clickable song tile for recommendations and artist catalog.
  Widget _buildRelatedSongTile(
    SongModel targetSong,
    MusicPlayerController controller,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          controller.playSong(targetSong);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: <Widget>[
              M3EAlbumArt(
                imageUrl: targetSong.thumbnailUrl,
                size: 44,
                radius: 4,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      targetSong.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${targetSong.artist} • ${targetSong.duration}',
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
            ],
          ),
        ),
      ),
    );
  }

  /// Helper row for track metadata description.
  Widget _buildTrackMetaRow(
    String label,
    String value,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
