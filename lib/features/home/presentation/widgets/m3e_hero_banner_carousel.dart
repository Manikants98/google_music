import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../models/song_model.dart';

/// Material 3 Expressive Hero Carousel with smooth deceleration and focal snap.
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
  late final M3ECarouselController _controller = M3ECarouselController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final accent = colorScheme.primary;

    // Take top 10 blockbuster hits for the carousel
    final displaySongs = widget.songs.take(10).toList();
    final double carouselHeight = isDesktop ? 240 : 210;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: carouselHeight,
        child: M3ETheme(
          data: M3ETheme.of(context).copyWith(
            carouselTheme: M3ETheme.of(context).carouselTheme.copyWith(
              smallMinWidth: 12,
              smallMaxWidth: 18,
              itemGap: 6,
              itemPadding: const EdgeInsets.symmetric(horizontal: 3),
            ),
          ),
          child: M3ECarousel(
            controller: _controller,
            type: M3ECarouselType.hero,
            axis: Axis.horizontal,
            heroAlignment: M3ECarouselHeroAlignment.center,
            largeMaxWidth: isDesktop ? 900 : 700,
            freeScroll: false,
            showAll: false,
            haptic: M3EHapticFeedback.light,
            childElementBorderRadius: 24,
            scrollAnimationDuration: 400,
            children: displaySongs.map((song) {
              final isCurrentActiveTrack =
                  widget.currentPlayingSong?.id == song.id;
              final isCurrentPlaying = isCurrentActiveTrack && widget.isPlaying;
              return M3ECarouselItem(
                onTap: () {
                  M3EHaptics.trigger(M3EHapticFeedback.light);
                  widget.onPlay(song, displaySongs);
                },
                image: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // 1. High-resolution album artwork backdrop
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (BuildContext context, String url, Object error) =>
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

                    // 2. Multi-stop cinematic dark gradient vignette
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const <double>[0.0, 0.35, 0.65, 1.0],
                            colors: <Color>[
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.90),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. Active Now Playing Badge Pill (Top-Right)
                    if (isCurrentPlaying)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.50),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.equalizer_rounded,
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'PLAYING',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 4. Bottom Info Bar: Song Info + Vibrant High-Contrast Play Button
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          // Left: Song Title & Artist
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
                                    fontSize: 16.5,
                                    letterSpacing: -0.2,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 8,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    letterSpacing: -0.1,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black,
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

                          // Right: Vibrant High-Contrast Play Button FAB
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isCurrentPlaying ? accent : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.40),
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
                              color: isCurrentPlaying
                                  ? colorScheme.onPrimary
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
