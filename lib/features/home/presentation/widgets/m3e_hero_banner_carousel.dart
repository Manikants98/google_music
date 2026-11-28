import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../models/song_model.dart';

/// ArchiveTune style Material 3 Expressive Hero Carousel.
///
/// Built directly with [M3ECarousel] from `material_3_expressive` using:
/// - [M3ECarouselType.hero]
/// - [M3ECarouselHeroAlignment.center]
/// - [M3ECarouselScrim.gradient]
/// - Large squircle curvature (28dp) with prominent hero card and peeking neighbors
/// - Floating circular Play button on the hero item
/// - Smooth auto-advance timer
class M3EHeroBannerCarousel extends StatefulWidget {
  /// List of featured songs to display in the carousel.
  final List<SongModel> songs;

  /// Active language filter for contextual queues.
  final String language;

  /// Callback when a song is tapped or its play button is pressed.
  final void Function(SongModel song, List<SongModel> queue) onPlay;

  /// The currently active playing track in the music player.
  final SongModel? currentPlayingSong;

  /// Whether the player is currently playing.
  final bool isPlaying;

  /// Creates a Material 3 Expressive hero carousel.
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
  late final M3ECarouselController _controller;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _controller = M3ECarouselController();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.songs.isEmpty) return;
      if (_controller.hasClients) {
        final total = widget.songs.take(10).length;
        if (total <= 1) return;
        final nextItem = (_controller.currentItem + 1) % total;
        _controller.animateToItem(
          nextItem,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final accent = colorScheme.primary;

    // Take top 8-10 hits for the expressive hero carousel
    final displaySongs = widget.songs.take(10).toList();
    final double carouselHeight = isDesktop ? 350 : 315;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 12,
              8,
              isDesktop ? 24 : 12,
              12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'FEATURED',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quick picks',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: carouselHeight,
            child: M3ECarousel(
              controller: _controller,
              type: M3ECarouselType.hero,
              axis: Axis.horizontal,
              heroAlignment: M3ECarouselHeroAlignment.center,
              freeScroll: false,
              showAll: true,
              children: displaySongs.map((song) {
                final isCurrentActiveTrack =
                    widget.currentPlayingSong?.id == song.id;
                final isCurrentPlaying =
                    isCurrentActiveTrack && widget.isPlaying;

                return M3ECarouselItem(
                  image: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CachedNetworkImage(
                        imageUrl: song.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (BuildContext context, String url) =>
                            Container(
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
                      // Floating circular Play Button (ArchiveTune style)
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isCurrentPlaying
                                ? colorScheme.primary
                                : colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isCurrentPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                            color: isCurrentPlaying
                                ? colorScheme.onPrimary
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      if (isCurrentActiveTrack)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
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
                        ),
                    ],
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(right: 56),
                    child: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 8,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(right: 56),
                    child: Text(
                      song.duration.isNotEmpty && song.duration != '--:--'
                          ? '${song.artist} • ${song.duration}'
                          : song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
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
                  ),
                  showScrim: const M3ECarouselScrim.gradient(),
                  onTap: () => widget.onPlay(song, displaySongs),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
