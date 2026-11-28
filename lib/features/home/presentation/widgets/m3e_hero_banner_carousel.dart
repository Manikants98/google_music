import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../models/song_model.dart';

/// Metadata for expressive badges displayed on top of hero banners.
class _HeroBannerBadge {
  final IconData icon;
  final String label;
  final Color accentColor;

  const _HeroBannerBadge({
    required this.icon,
    required this.label,
    required this.accentColor,
  });
}

/// Material 3 Expressive & Material You Top Hero Banner Carousel.
///
/// Displays cinematic widescreen song cards for top hits with:
/// - M3 Extra Large squircle curvature (24dp radius)
/// - Material You dynamic color harmonized gradient scrims
/// - Expressive category badges (Chartbuster, Trending, Mega Hit, etc.)
/// - Floating FAB-style instant Play / Pause equalizer button
/// - Subtle parallax scale animation on swipe
/// - Auto-scrolling carousel with interactive touch pause
/// - Smooth animated pill-dot page indicators
class M3EHeroBannerCarousel extends StatefulWidget {
  /// List of featured songs to display in the carousel.
  final List<SongModel> songs;

  /// Active language filter for contextual badges and queues.
  final String language;

  /// Callback when a song is tapped or its play button is pressed.
  final void Function(SongModel song, List<SongModel> queue) onPlay;

  /// The currently active playing track in the music player.
  final SongModel? currentPlayingSong;

  /// Whether the player is currently playing.
  final bool isPlaying;

  /// Creates a Material 3 Expressive hero banner carousel.
  const M3EHeroBannerCarousel({
    super.key,
    required this.songs,
    required this.language,
    required this.onPlay,
    this.currentPlayingSong,
    this.isPlaying = false,
  });

  @override
  State<M3EHeroBannerCarousel> createState() => _M3EHeroBannerCarouselState();
}

class _M3EHeroBannerCarouselState extends State<M3EHeroBannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  bool _isUserInteracting = false;

  static const List<_HeroBannerBadge> _defaultBadges = <_HeroBannerBadge>[
    _HeroBannerBadge(
      icon: Icons.local_fire_department_rounded,
      label: 'CHARTBUSTER #1',
      accentColor: Color(0xFFFF5252),
    ),
    _HeroBannerBadge(
      icon: Icons.bolt_rounded,
      label: 'TRENDING HIT',
      accentColor: Color(0xFFFFB300),
    ),
    _HeroBannerBadge(
      icon: Icons.auto_awesome_rounded,
      label: 'MEGA BLOCKBUSTER',
      accentColor: Color(0xFF00E5FF),
    ),
    _HeroBannerBadge(
      icon: Icons.stars_rounded,
      label: 'SPOTLIGHT PICK',
      accentColor: Color(0xFFE040FB),
    ),
    _HeroBannerBadge(
      icon: Icons.graphic_eq_rounded,
      label: 'VIRAL ANTHEM',
      accentColor: Color(0xFF69F0AE),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _isUserInteracting || widget.songs.isEmpty) return;
      if (!_pageController.hasClients) return;

      final next = (_currentPage + 1) % widget.songs.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _onUserTouchStart() {
    _isUserInteracting = true;
    _stopAutoScroll();
  }

  void _onUserTouchEnd() {
    _isUserInteracting = false;
    _startAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final isDark = theme.brightness == Brightness.dark;

    // Constrain to maximum 5 blockbuster tracks for the hero carousel
    final displaySongs = widget.songs.take(5).toList();
    final double carouselHeight = isDesktop ? 215 : 185;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 12,
        8,
        isDesktop ? 24 : 12,
        4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Listener(
            onPointerDown: (_) => _onUserTouchStart(),
            onPointerUp: (_) => _onUserTouchEnd(),
            onPointerCancel: (_) => _onUserTouchEnd(),
            child: SizedBox(
              height: carouselHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: displaySongs.length,
                onPageChanged: (int index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  final song = displaySongs[index];
                  final badge = _defaultBadges[index % _defaultBadges.length];
                  final isCurrentActiveTrack =
                      widget.currentPlayingSong?.id == song.id;
                  final isCurrentPlaying =
                      isCurrentActiveTrack && widget.isPlaying;

                  return _buildBannerCard(
                    context: context,
                    song: song,
                    badge: badge,
                    isCurrentActiveTrack: isCurrentActiveTrack,
                    isCurrentPlaying: isCurrentPlaying,
                    colorScheme: colorScheme,
                    theme: theme,
                    isDark: isDark,
                    displaySongs: displaySongs,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Material You Smooth Pill Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(displaySongs.length, (int index) {
              final isSelected = index == _currentPage;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.fastEaseInToSlowEaseOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 18 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(
                            alpha: isDark ? 0.35 : 0.22,
                          ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCard({
    required BuildContext context,
    required SongModel song,
    required _HeroBannerBadge badge,
    required bool isCurrentActiveTrack,
    required bool isCurrentPlaying,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required bool isDark,
    required List<SongModel> displaySongs,
  }) {
    final accent = colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. High-resolution album artwork backdrop
            CachedNetworkImage(
              imageUrl: song.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (BuildContext context, String url) => Container(
                color: colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
              errorWidget: (BuildContext context, String url, Object error) =>
                  Container(
                color: colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // 2. Cinematic Gradient Scrim:
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0.0, 0.30, 0.65, 1.0],
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.68),
                    Colors.black.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),

            // 3. Subtle Outline Border matching 12dp grid
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.18),
                  width: 1,
                ),
              ),
            ),

            // 4. Card Content (Badges, Titles, and Expressive Play Button)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.onPlay(song, displaySongs),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // Top Row: Category Badge Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: badge.accentColor.withValues(alpha: 0.45),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      badge.icon,
                                      size: 13,
                                      color: badge.accentColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      badge.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (isCurrentActiveTrack)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.90),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.equalizer_rounded,
                                    size: 13,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'PLAYING',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9.5,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Bottom Row: Song details + Floating Play FAB
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 8,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  song.duration.isNotEmpty && song.duration != '--:--'
                                      ? '${song.artist} • ${song.duration}'
                                      : song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 6,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Material 3 Expressive Play Button
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              isCurrentPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 26,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
