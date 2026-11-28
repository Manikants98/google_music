import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../models/song_model.dart';

/// Material 3 Expressive Widescreen Hero Carousel with Infinite Scroll.
///
/// Features:
/// - Widescreen hero proportion (center card flex: 7, side peeks flex: 1)
/// - True infinite loop scrolling in both directions
/// - Smooth snap physics on swipe
/// - M3 squircle curvature (24dp radius)
/// - Floating circular Play button with equalizer indicator
class M3EHeroBannerCarousel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final accent = colorScheme.primary;

    // Take top 10 blockbuster hits for the carousel
    final displaySongs = songs.take(10).toList();
    final double carouselHeight = isDesktop ? 240 : 205;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: SizedBox(
        height: carouselHeight,
        child: M3ECarouselView.weighted(
          flexWeights: isDesktop ? const <int>[1, 8, 1] : const <int>[1, 7, 1],
          infinite: true,
          itemSnapping: true,
          consumeMaxWeight: false,
          shrinkExtent: 0.0,
          scaleItems: true,
          haptic: M3EHapticFeedback.light,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onTap: (int index) {
            M3EHaptics.trigger(M3EHapticFeedback.light);
            final song = displaySongs[index % displaySongs.length];
            onPlay(song, displaySongs);
          },
          children: displaySongs.map((song) {
            final isCurrentActiveTrack = currentPlayingSong?.id == song.id;
            final isCurrentPlaying = isCurrentActiveTrack && isPlaying;

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
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

                  // 2. Cinematic Gradient Scrim
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const <double>[0.0, 0.35, 0.68, 1.0],
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.40),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                          Colors.black.withValues(alpha: 0.94),
                        ],
                      ),
                    ),
                  ),

                  // 3. Subtle Outline Border
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.12
                              : 0.20,
                        ),
                        width: 1,
                      ),
                    ),
                  ),

                  // 4. Playing Badge (Top-Right)
                  if (isCurrentActiveTrack)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.equalizer_rounded,
                              size: 13,
                              color: Colors.black,
                            ),
                            SizedBox(width: 4),
                            Text(
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

                  // 5. Song Details (Bottom-Left)
                  Positioned(
                    left: 14,
                    bottom: 12,
                    right: 64,
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
                        const SizedBox(height: 2),
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

                  // 6. Floating Circular Play Button (Bottom-Right)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isCurrentPlaying
                            ? colorScheme.primary
                            : colorScheme.primaryContainer,
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
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
