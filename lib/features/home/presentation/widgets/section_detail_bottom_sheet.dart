import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../../core/audio/music_player_controller.dart';
import '../../../../core/widgets/m3e_widgets.dart';
import '../../../../models/song_model.dart';

/// Modal bottom sheet displaying the complete list of songs related to a specific category section.
class SectionDetailBottomSheet extends StatefulWidget {
  /// Category eyebrow tag (e.g. ROMANTIC & SOUL).
  final String label;

  /// Section headline title (e.g. Bollywood Romance).
  final String title;

  /// Initial tracks provided from the home screen section.
  final List<SongModel> initialTracks;

  /// Active language context.
  final String language;

  /// Creates section detail bottom sheet.
  const SectionDetailBottomSheet({
    super.key,
    required this.label,
    required this.title,
    required this.initialTracks,
    required this.language,
  });

  @override
  State<SectionDetailBottomSheet> createState() =>
      _SectionDetailBottomSheetState();
}

class _SectionDetailBottomSheetState extends State<SectionDetailBottomSheet> {
  late List<SongModel> _tracks;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tracks = List<SongModel>.from(widget.initialTracks);
    _loadRelatedTracks();
  }

  /// Fetches richer catalog of songs specifically related to this section's genre and title.
  Future<void> _loadRelatedTracks() async {
    if (_tracks.length >= 15) return;

    setState(() {
      _isLoadingMore = true;
    });

    final controller = context.read<MusicPlayerController>();
    final query = '${widget.language} ${widget.title} official songs';
    final related = await controller.innerTubeClient.search(query);

    if (mounted) {
      final existingIds = _tracks.map((s) => s.id).toSet();
      final fresh = related.where((s) => !existingIds.contains(s.id)).toList();

      setState(() {
        _tracks.addAll(fresh);
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_tracks.isNotEmpty) ...<Widget>[
                    M3EButton(
                      decoration: const M3EButtonDecoration(
                        haptic: M3EHapticFeedback.light,
                      ),
                      label: const Text('Play all'),
                      style: M3EButtonStyle.tonal,
                      size: M3EButtonSize.sm,
                      onPressed: () {
                        controller.playSong(_tracks.first, newQueue: _tracks);
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        controller.isPlaylistFullyDownloaded(_tracks)
                            ? Icons.download_done_rounded
                            : (controller.isPlaylistDownloading(_tracks)
                                ? Icons.hourglass_top_rounded
                                : Icons.download_rounded),
                        size: 20,
                        color: controller.isPlaylistFullyDownloaded(_tracks)
                            ? controller.dynamicAccentColor
                            : colorScheme.onSurfaceVariant,
                      ),
                      tooltip: controller.isPlaylistFullyDownloaded(_tracks)
                          ? 'All tracks downloaded'
                          : 'Download all tracks',
                      onPressed: () {
                        M3EHaptics.trigger(M3EHapticFeedback.light);
                        if (controller.isPlaylistFullyDownloaded(_tracks)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'All tracks in this section are already saved offline.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          controller.downloadSongsBatch(_tracks);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Downloading ${_tracks.length} tracks in background...',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            Expanded(
              child: _tracks.isEmpty
                  ? Center(
                      child: Text(
                        'No songs available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      children: <Widget>[
                        M3EList(
                          color: colorScheme.surfaceContainerHighest,
                          outerRadius: 12,
                          innerRadius: 4,
                          gap: 2,
                          haptic: M3EHapticFeedback.light,
                          itemCount: _tracks.length,
                          onTap: (int index) {
                            M3ESongTile.handleTap(
                              context,
                              _tracks[index],
                              queue: _tracks,
                            );
                          },
                          itemBuilder: (BuildContext context, int index) {
                            return M3ESongTile(
                              song: _tracks[index],
                            );
                          },
                        ),
                        if (_isLoadingMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: controller.dynamicAccentColor,
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
    );
  }
}
