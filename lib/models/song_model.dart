/// Domain model representing a music track.
class SongModel {
  /// Unique YouTube video ID.
  final String id;

  /// Song or video title.
  final String title;

  /// Channel or artist name.
  final String artist;

  /// High-resolution thumbnail image URL.
  final String thumbnailUrl;

  /// Formatted duration string (e.g. 03:45).
  final String duration;

  /// Cached audio stream URL once extracted.
  String? audioStreamUrl;

  /// Whether the track is liked by the user.
  bool isLiked;

  /// Constructor for creating a song track.
  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    this.duration = '--:--',
    this.audioStreamUrl,
    this.isLiked = false,
  });

  /// Parses formatted duration string (e.g. '03:45' or '1:12:30') into a [Duration].
  Duration? get parsedDuration {
    if (duration.isEmpty || duration == '--:--') return null;
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0].trim());
        final seconds = int.parse(parts[1].trim());
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0].trim());
        final minutes = int.parse(parts[1].trim());
        final seconds = int.parse(parts[2].trim());
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (_) {}
    return null;
  }

  /// Factory constructor to parse InnerTube videoRenderer map.
  factory SongModel.fromInnerTube(Map<String, dynamic> renderer) {
    final videoId = (renderer['videoId'] ?? '').toString();

    final titleRuns = renderer['title']?['runs'];
    final rawTitle = (titleRuns is List && titleRuns.isNotEmpty)
        ? titleRuns[0]['text'].toString()
        : 'Unknown Track';

    final ownerRuns =
        renderer['ownerText']?['runs'] ?? renderer['shortBylineText']?['runs'];
    final rawArtist = (ownerRuns is List && ownerRuns.isNotEmpty)
        ? ownerRuns[0]['text'].toString()
        : 'Google Music';

    final thumbs = renderer['thumbnail']?['thumbnails'];
    String thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    if (thumbs is List && thumbs.isNotEmpty) {
      final bestThumb = thumbs.last['url']?.toString() ?? '';
      if (bestThumb.isNotEmpty) {
        thumbUrl = getHighResThumbnail(bestThumb);
      }
    }

    final lengthText =
        renderer['lengthText']?['simpleText']?.toString() ?? '--:--';

    return SongModel(
      id: videoId,
      title: _sanitizeTitle(rawTitle),
      artist: _sanitizeArtist(rawArtist),
      thumbnailUrl: thumbUrl,
      duration: lengthText,
    );
  }

  /// Factory constructor to parse YouTube Music musicResponsiveListItemRenderer map.
  factory SongModel.fromYouTubeMusic(Map<String, dynamic> rli) {
    final videoId =
        (rli['playlistItemData']?['videoId'] ??
                rli['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'] ??
                '')
            .toString();

    final flexCols = rli['flexColumns'];
    String rawTitle = 'Unknown Track';
    String rawArtist = 'Google Music';
    String duration = '--:--';

    if (flexCols is List && flexCols.isNotEmpty) {
      final titleRuns =
          flexCols[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      if (titleRuns is List && titleRuns.isNotEmpty) {
        rawTitle = titleRuns.map((r) => r['text']?.toString() ?? '').join();
      }

      if (flexCols.length > 1) {
        final infoRuns =
            flexCols[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
        if (infoRuns is List && infoRuns.isNotEmpty) {
          final List<String> artistParts = <String>[];
          for (final run in infoRuns) {
            final text = run['text']?.toString() ?? '';
            if (text.contains('•')) {
              break;
            }
            artistParts.add(text);
          }
          if (artistParts.isNotEmpty) {
            rawArtist = artistParts.join().trim();
          }

          for (final run in infoRuns.reversed) {
            final text = run['text']?.toString().trim() ?? '';
            if (RegExp(r'^\d+:\d+(:\d+)?$').hasMatch(text)) {
              duration = text;
              break;
            }
          }
        }
      }
    }

    final fixedCols = rli['fixedColumns'];
    if (fixedCols is List && fixedCols.isNotEmpty) {
      final durRuns =
          fixedCols[0]['musicResponsiveListItemFixedColumnRenderer']?['text']?['runs'];
      if (durRuns is List && durRuns.isNotEmpty) {
        final text = durRuns[0]['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          duration = text;
        }
      }
    }

    String thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    final thumbs =
        rli['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
    if (thumbs is List && thumbs.isNotEmpty) {
      final bestThumb = thumbs.last['url']?.toString() ?? '';
      if (bestThumb.isNotEmpty) {
        thumbUrl = getHighResThumbnail(bestThumb);
      }
    }

    return SongModel(
      id: videoId,
      title: _sanitizeTitle(rawTitle),
      artist: _sanitizeArtist(rawArtist),
      thumbnailUrl: thumbUrl,
      duration: duration,
    );
  }

  /// Factory constructor to parse YouTube Music playlistPanelVideoRenderer map (Up Next & Radio recommendations).
  factory SongModel.fromPlaylistPanel(Map<String, dynamic> item) {
    final videoId = (item['videoId'] ?? '').toString();

    String rawTitle = 'Unknown Track';
    final titleRuns = item['title']?['runs'];
    if (titleRuns is List && titleRuns.isNotEmpty) {
      rawTitle = titleRuns.map((r) => r['text']?.toString() ?? '').join();
    }

    String rawArtist = 'Google Music';
    final bylineRuns = item['longBylineText']?['runs'] ??
        item['shortBylineText']?['runs'];
    if (bylineRuns is List && bylineRuns.isNotEmpty) {
      final List<String> artistParts = <String>[];
      for (final run in bylineRuns) {
        final text = run['text']?.toString() ?? '';
        if (text.contains('•')) break;
        artistParts.add(text);
      }
      if (artistParts.isNotEmpty) {
        rawArtist = artistParts.join().trim();
      }
    }

    String duration = '--:--';
    final lenRuns = item['lengthText']?['runs'];
    if (lenRuns is List && lenRuns.isNotEmpty) {
      duration = (lenRuns[0]['text'] ?? '--:--').toString();
    }

    String thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    final thumbs = item['thumbnail']?['thumbnails'];
    if (thumbs is List && thumbs.isNotEmpty) {
      final bestThumb = thumbs.last['url']?.toString() ?? '';
      if (bestThumb.isNotEmpty) {
        thumbUrl = getHighResThumbnail(bestThumb);
      }
    }

    return SongModel(
      id: videoId,
      title: _sanitizeTitle(rawTitle),
      artist: _sanitizeArtist(rawArtist),
      thumbnailUrl: thumbUrl,
      duration: duration,
    );
  }

  /// Converts track to a serializable map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'audioStreamUrl': audioStreamUrl,
      'isLiked': isLiked,
    };
  }

  /// Factory constructor to parse stored map.
  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: (map['id'] ?? '').toString(),
      title: _sanitizeTitle((map['title'] ?? 'Unknown').toString()),
      artist: _sanitizeArtist((map['artist'] ?? 'Unknown').toString()),
      thumbnailUrl: getHighResThumbnail((map['thumbnailUrl'] ?? '').toString()),
      duration: (map['duration'] ?? '--:--').toString(),
      audioStreamUrl: map['audioStreamUrl'] as String?,
      isLiked: map['isLiked'] == true,
    );
  }

  /// Cleans HTML entities, bracketed labels, and official audio/video suffixes.
  static String _sanitizeTitle(String raw) {
    String text = raw
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'");

    /// Strips any emoji symbols from title.
    text = text.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}]',
        unicode: true,
      ),
      '',
    );

    /// Strips leading video/audio prefixes such as "Full Video:", "Lyrical:", "Full Song:", "Video Song:".
    text = text.replaceAll(
      RegExp(
        r'''^\s*['"“”‘’]?\s*(?:full\s*(?:video\s*song|video|song|audio\s*song|audio)|lyrical\s*(?:video\s*song|video|song|track)?|lyric\s*(?:video|song)?|lyrics|video\s*song|video|official\s*(?:music\s*video|video\s*song|video|audio\s*song|audio|track)?|audio\s*song|audio|visualizer|teaser|promo|(?:8k|4k|hd)\s*(?:video|song|audio)?)\s*[:|\-–—]\s*['"“”‘’]?\s*''',
        caseSensitive: false,
      ),
      '',
    );

    /// Removes bracketed or parenthesized official tags, audio, video, lyrics labels.
    text = text.replaceAll(
      RegExp(
        r'\s*[\(\[\{][^\)\]\}]*(?:official|audio|video|lyric|song|visualizer|remastered|full\s*song|bonus\s*track|hd|4k|8k)[^\)\]\}]*[\)\]\}]',
        caseSensitive: false,
      ),
      '',
    );

    /// Removes any remaining square bracket tags like [4K], [HD].
    text = text.replaceAll(RegExp(r'\s*\[.*?\]'), '');

    /// Removes inline video, audio, or full song tags.
    text = text.replaceAll(
      RegExp(
        r'''\s*(?:[-–—]\s*)?\b(?:full\s*video\s*song|full\s*video|full\s*song|full\s*audio\s*song|full\s*audio|video\s*song|audio\s*song|lyrical\s*video\s*song|lyrical\s*video|lyrical\s*song|lyric\s*video|official\s*music\s*video|official\s*video\s*song|official\s*video|official\s*audio\s*song|official\s*audio|official\s*song|8k\s*video\s*song|8k\s*video|4k\s*video\s*song|4k\s*video|hd\s*video\s*song|hd\s*video|bonus\s*track|8k|4k|hd|official)\b''',
        caseSensitive: false,
      ),
      '',
    );

    /// Removes trailing video, audio, or official labels separated by pipe, dash, or slash.
    text = text.replaceAll(
      RegExp(
        r'\s*[|\-–—/:]\s*(?:official\s*)?(?:music\s*video|video\s*song|video|audio|song|lyric|lyrical|hd|4k|track)\b.*$',
        caseSensitive: false,
      ),
      '',
    );

    /// Strips any standalone occurrence of the word official.
    text = text.replaceAll(RegExp(r'\bofficial\b', caseSensitive: false), '');

    /// Cleans orphaned empty pipes or duplicate separators.
    text = text.replaceAll(RegExp(r'\s*[|]\s*[|]+'), ' |');
    text = text.replaceAll(RegExp(r'\s*[-–—]\s*[-–—]+'), ' -');

    /// Strips leading and trailing punctuation separators, quotes, and whitespace.
    text = text.replaceAll(
      RegExp(r'''^[|\-–—/:\s'"“”‘’]+|[|\-–—/:\s'"“”‘’]+$'''),
      '',
    );

    /// Collapses consecutive whitespaces into a single space.
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Cleans artist channel names by removing topic suffixes and official badges.
  static String _sanitizeArtist(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}]',
            unicode: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bofficial\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Public helper to sanitize raw titles.
  static String sanitizeTitle(String raw) => _sanitizeTitle(raw);

  /// Public helper to sanitize raw artists.
  static String sanitizeArtist(String raw) => _sanitizeArtist(raw);

  /// Extracts a normalized title fingerprint for deduplicating identical songs uploaded under different video IDs.
  static String normalizeFingerprint(String title) {
    if (title.isEmpty) return '';

    /// Take primary title segment before delimiters (|, -, •, :, —, /, ~).
    final segments = title.split(RegExp(r'[|\-•:—/~]'));
    final primary = segments.first.trim();
    final target = primary.length >= 3 ? primary : title;

    String clean = target.toLowerCase();
    clean = clean.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
    clean = clean.replaceAll(
      RegExp(
        r'\b(8k|4k|hd|video|official|audio|song|songs|full|lyrics|lyrical|track|original|teaser|trailer|remix|bonus|version|ver)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    clean = clean.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length >= 3 ? clean : '';
  }

  /// Transforms low-resolution thumbnail URLs into high-definition (HD) master album art.
  static String getHighResThumbnail(String url) {
    if (url.isEmpty) return url;

    /// 1. Handle Google User Content (YouTube Music album art, e.g. yt3.googleusercontent.com).
    if (url.contains('googleusercontent.com')) {
      if (url.contains(RegExp(r'=w\d+-h\d+'))) {
        return url.replaceAll(RegExp(r'=w\d+-h\d+'), '=w800-h800');
      }
      if (url.contains(RegExp(r'=s\d+'))) {
        return url.replaceAll(RegExp(r'=s\d+'), '=s800');
      }
      if (!url.contains('=')) {
        return '$url=w800-h800-l90-rj';
      }
    }

    /// 2. Handle YouTube standard thumbnails (e.g. i.ytimg.com).
    if (url.contains('i.ytimg.com')) {
      if (url.contains('default.jpg') &&
          !url.contains('hqdefault.jpg') &&
          !url.contains('maxresdefault.jpg')) {
        return url
            .replaceAll('default.jpg', 'hqdefault.jpg')
            .replaceAll('mqdefault.jpg', 'hqdefault.jpg');
      }
    }

    return url;
  }
}
