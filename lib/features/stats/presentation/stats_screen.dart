import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/widgets/m3e_widgets.dart';

/// Screen presenting user's personal listening statistics, analytics, and music insights.
class StatsScreen extends StatefulWidget {
  /// Creates stats screen.
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedRange = 'Years';

  final List<String> _ranges = const <String>[
    'Continuous',
    'Weeks',
    'Months',
    'Years',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();
    final tracker = controller.behaviorTracker;

    final isDesktop = MediaQuery.sizeOf(context).width > 850;
    final hPad = isDesktop ? 24.0 : 12.0;
    final accent = controller.dynamicAccentColor;

    // Compute stats
    final totalListenSeconds = tracker.totalListenSeconds;
    final totalMinutes = totalListenSeconds ~/ 60;
    final durationHours = totalMinutes ~/ 60;
    final durationRemainingMins = totalMinutes % 60;
    final formattedTime = durationHours > 0
        ? '${durationHours}h ${durationRemainingMins}m'
        : '$totalMinutes mins';
    final clockFormatted = '${(totalMinutes).toString().padLeft(2, '0')}:${(totalListenSeconds % 60).toString().padLeft(2, '0')}';

    final totalPlays = tracker.totalPlays;
    final uniqueSongs = tracker.uniqueSongsCount;
    final uniqueArtists = tracker.uniqueArtistsCount;
    final likedCount = controller.likedSongs.length;

    final favArtist = tracker.getFavoriteArtistDetails();
    final topSongs = tracker.getMostPlayedSongs(
      limit: 5,
      fallbackTracks: controller.likedSongs.isNotEmpty ? controller.likedSongs : controller.history,
    );
    final topArtists = tracker.getTopArtists(limit: 5);
    final langAffinities = tracker.languageAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        titleSpacing: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Stats',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$_selectedRange • $currentYear',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.auto_awesome_rounded, color: accent),
            tooltip: 'Music Recap',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Listening Stats: $totalMinutes minutes listened across $totalPlays plays!',
                  ),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          SizedBox(width: isDesktop ? 18 : 6),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
        children: <Widget>[
          // ----------------------------------------------------
          // 1. TIME RANGE CARD
          // ----------------------------------------------------
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Time range',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _ranges.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final range = _ranges[index];
                      final isSelected = range == _selectedRange;
                      return M3EChip(
                        label: range,
                        type: M3EChipType.filter,
                        selected: isSelected,
                        onPressed: () {
                          setState(() {
                            _selectedRange = range;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedRange == 'Years' ? '$currentYear' : _selectedRange,
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

          const SizedBox(height: 12),

          // ----------------------------------------------------
          // 2. HERO CARD: TOTAL TIME LISTENED
          // ----------------------------------------------------
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                accent.withValues(alpha: 0.16),
                colorScheme.surfaceContainerHighest,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: <Widget>[
                // Decorative wave / music icon in background
                Positioned(
                  right: -10,
                  bottom: -15,
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 110,
                    color: accent.withValues(alpha: 0.08),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedRange == 'Years' ? '$currentYear' : _selectedRange,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Total Time Listened',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalMinutes',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'minutes • $clockFormatted ($formattedTime)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ----------------------------------------------------
          // 3. 2x2 METRICS BENTO GRID
          // ----------------------------------------------------
          Row(
            children: <Widget>[
              // Total Plays
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.play_arrow_rounded,
                  value: '$totalPlays',
                  label: 'Total Plays',
                  accent: accent,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              // Unique Songs
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.music_note_rounded,
                  value: '$uniqueSongs',
                  label: 'Unique Songs',
                  accent: accent,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: <Widget>[
              // Unique Artists
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.person_rounded,
                  value: '$uniqueArtists',
                  label: 'Unique Artists',
                  accent: accent,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              // Liked Songs
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.favorite_rounded,
                  value: '$likedCount',
                  label: 'Liked Songs',
                  accent: accent,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ----------------------------------------------------
          // 4. YOUR FAVOURITE ARTIST CARD
          // ----------------------------------------------------
          if (favArtist != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  accent.withValues(alpha: 0.14),
                  colorScheme.surfaceContainerHighest,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  // Artist Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: favArtist.thumbnailUrl != null &&
                              favArtist.thumbnailUrl!.isNotEmpty
                          ? Image.network(
                              favArtist.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, stack) => Container(
                                color: colorScheme.surfaceContainerHigh,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 36,
                                ),
                              ),
                            )
                          : Container(
                              color: colorScheme.surfaceContainerHigh,
                              child: Icon(
                                Icons.person_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 36,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Artist Info & Chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Your Favourite Artist',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          favArtist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.play_arrow_rounded, size: 14, color: accent),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${favArtist.playCount} times',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (favArtist.dwellSeconds > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${favArtist.dwellSeconds ~/ 60}:${(favArtist.dwellSeconds % 60).toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ----------------------------------------------------
          // 5. TOP 5 MOST PLAYED SONGS
          // ----------------------------------------------------
          if (topSongs.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'TOP TRACKS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            M3EList(
              color: colorScheme.surfaceContainerHighest,
              outerRadius: 12,
              innerRadius: 4,
              gap: 2,
              itemCount: topSongs.length,
              onTap: (int index) {
                M3ESongTile.handleTap(context, topSongs[index], queue: topSongs);
              },
              itemBuilder: (BuildContext context, int index) {
                final song = topSongs[index];
                final plays = tracker.getPlayCount(song.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      // Rank number
                      SizedBox(
                        width: 24,
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: index == 0 ? accent : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Album art
                      M3EAlbumArt(
                        imageUrl: song.thumbnailUrl,
                        size: 44,
                        radius: 6,
                        elevation: 1,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
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
                      if (plays > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$plays plays',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
          ],

          // ----------------------------------------------------
          // 6. TOP ARTISTS LIST
          // ----------------------------------------------------
          if (topArtists.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'TOP ARTISTS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            M3EList(
              color: colorScheme.surfaceContainerHighest,
              outerRadius: 12,
              innerRadius: 4,
              gap: 2,
              itemCount: topArtists.length,
              itemBuilder: (BuildContext context, int index) {
                final artist = topArtists[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      // Rank number
                      SizedBox(
                        width: 24,
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: index == 0 ? accent : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Circle Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: artist.thumbnailUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  artist.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, err, stack) => Icon(
                                    Icons.person_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                    size: 22,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${artist.playCount} plays',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
          ],

          // ----------------------------------------------------
          // 7. LANGUAGE & GENRE VIBES
          // ----------------------------------------------------
          if (langAffinities.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'YOUR VIBES & GENRES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: langAffinities.map((entry) {
                  final capitalized = entry.key[0].toUpperCase() + entry.key.substring(1);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.graphic_eq_rounded, size: 14, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          capitalized,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // Metric 1-card widget
  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
