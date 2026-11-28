import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/playlist_model.dart';
import '../../models/song_model.dart';

/// Lightweight InnerTube client for fast search, discovery, and infinite scroll pagination without API keys.
class InnerTubeClient {
  /// Official YouTube Music search endpoint for rich official studio songs.
  static const String _ytMusicSearchEndpoint =
      'https://music.youtube.com/youtubei/v1/search';

  /// Official YouTube Music next endpoint for radio, queue, and watch next recommendations.
  static const String _ytMusicNextEndpoint =
      'https://music.youtube.com/youtubei/v1/next';

  /// Desktop client headers for YouTube Music.
  static const Map<String, String> _ytMusicHeaders = <String, String>{
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Referer': 'https://music.youtube.com/',
  };

  /// Songs filter param in YouTube Music to return strictly music tracks (no vlogs/podcasts).
  static const String _songsFilterParam =
      'EgWKAQIIAWoMEAMQBBAJEAoQBRAREAU%3D';

  /// In-memory cache for genre queries.
  final Map<String, List<SongModel>> _cachedGenreResults =
      <String, List<SongModel>>{};

  /// In-memory cache for trending tracks.
  List<SongModel> _cachedTrending = <SongModel>[];

  /// Continuation tokens stored per language category for YouTube pagination.
  final Map<String, String> _continuationTokens = <String, String>{};

  /// Extracts a normalized title fingerprint for deduplicating identical songs uploaded under different video IDs.
  static String normalizeFingerprint(String title) =>
      SongModel.normalizeFingerprint(title);

  /// Executes a search request exclusively on YouTube Music API for official studio songs and square HD artwork.
  Future<List<SongModel>> _postSearch(
    String query, {
    String? continuationToken,
    String? languageKey,
  }) async {
    /// 1. Try YouTube Music API with official songs filter.
    try {
      final Map<String, dynamic> ytMusicPayload = <String, dynamic>{
        'context': <String, dynamic>{
          'client': <String, dynamic>{
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20230522.01.00',
            'hl': 'en',
            'gl': 'IN',
          },
        },
      };

      if (continuationToken != null && continuationToken.isNotEmpty) {
        ytMusicPayload['continuation'] = continuationToken;
      } else {
        ytMusicPayload['query'] = query;
        ytMusicPayload['params'] = _songsFilterParam;
      }

      final response = await http
          .post(
            Uri.parse(_ytMusicSearchEndpoint),
            headers: _ytMusicHeaders,
            body: json.encode(ytMusicPayload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final List<SongModel> songs = _parseYouTubeMusicResults(
            decoded,
            languageKey: languageKey,
          );
          if (songs.isNotEmpty) {
            return songs;
          }
        }
      }
    } catch (_) {}

    /// 2. If filtered search yields empty, retry YouTube Music without filter params.
    if (continuationToken == null || continuationToken.isEmpty) {
      try {
        final Map<String, dynamic> fallbackPayload = <String, dynamic>{
          'context': <String, dynamic>{
            'client': <String, dynamic>{
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20230522.01.00',
              'hl': 'en',
              'gl': 'IN',
            },
          },
          'query': query,
        };

        final response = await http
            .post(
              Uri.parse(_ytMusicSearchEndpoint),
              headers: _ytMusicHeaders,
              body: json.encode(fallbackPayload),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            final List<SongModel> songs = _parseYouTubeMusicResults(
              decoded,
              languageKey: languageKey,
            );
            if (songs.isNotEmpty) {
              return songs;
            }
          }
        }
      } catch (_) {}
    }

    return <SongModel>[];
  }

  /// Parses YouTube Music search and continuation response format.
  List<SongModel> _parseYouTubeMusicResults(
    Map<String, dynamic> decoded, {
    String? languageKey,
  }) {
    final List<SongModel> results = <SongModel>[];
    final Set<String> localIds = <String>{};
    final Set<String> localFingerprints = <String>{};

    void processItem(dynamic item) {
      if (item is! Map<String, dynamic>) return;
      final rli = item['musicResponsiveListItemRenderer'];
      if (rli is Map<String, dynamic>) {
        final song = SongModel.fromYouTubeMusic(rli);
        final fp = SongModel.normalizeFingerprint(song.title);
        if (song.id.isNotEmpty &&
            _isValidMusicTrack(song) &&
            !localIds.contains(song.id) &&
            (fp.isEmpty || !localFingerprints.contains(fp))) {
          results.add(song);
          localIds.add(song.id);
          if (fp.isNotEmpty) {
            localFingerprints.add(fp);
          }
        }
      }
    }

    /// Normal search response tabs & shelves.
    final sections = decoded['contents']?['tabbedSearchResultsRenderer']
        ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
        ?['contents'];

    if (sections is List) {
      for (final section in sections) {
        final shelf = section['musicShelfRenderer'];
        if (shelf is Map<String, dynamic>) {
          final continuations = shelf['continuations'];
          if (continuations is List && continuations.isNotEmpty) {
            final token =
                continuations[0]?['nextContinuationData']?['continuation'];
            if (token is String && languageKey != null) {
              _continuationTokens[languageKey] = token;
            }
          }
          final contents = shelf['contents'];
          if (contents is List) {
            for (final item in contents) {
              processItem(item);
            }
          }
        }
      }
    }

    /// Continuation response format.
    final continuationShelf =
        decoded['continuationContents']?['musicShelfContinuation'];
    if (continuationShelf is Map<String, dynamic>) {
      final continuationsList = continuationShelf['continuations'];
      if (continuationsList is List && continuationsList.isNotEmpty) {
        final token =
            continuationsList[0]?['nextContinuationData']?['continuation'];
        if (token is String && languageKey != null) {
          _continuationTokens[languageKey] = token;
        }
      }
      final contents = continuationShelf['contents'];
      if (contents is List) {
        for (final item in contents) {
          processItem(item);
        }
      }
    }

    return results;
  }

  /// Supported official music languages.
  static const List<String> supportedLanguages = <String>[
    'Hindi',
    'English',
    'Punjabi',
    'Haryanvi',
  ];

  /// Searches for music tracks prioritizing official audio and studio releases.
  Future<List<SongModel>> search(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return <SongModel>[];

    final directResults = await _postSearch(cleaned);
    if (directResults.isNotEmpty) {
      return directResults;
    }

    final fallbackQuery = '$cleaned song';
    return await _postSearch(fallbackQuery);
  }

  /// Searches for playlists matching [query] using YouTube Music community playlist filter.
  Future<List<PlaylistModel>> searchPlaylists(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return <PlaylistModel>[];

    try {
      final Map<String, dynamic> ytMusicPayload = <String, dynamic>{
        'context': <String, dynamic>{
          'client': <String, dynamic>{
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20230522.01.00',
            'hl': 'en',
            'gl': 'IN',
          },
        },
        'query': cleaned,
        'params': 'Eg-KAQwIABAAGAAgACgBMA8%3D',
      };

      final response = await http
          .post(
            Uri.parse(_ytMusicSearchEndpoint),
            headers: _ytMusicHeaders,
            body: json.encode(ytMusicPayload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return _parseYouTubeMusicPlaylists(decoded);
        }
      }
    } catch (e) {
      debugPrint('[InnerTube] Playlist search failed: $e');
    }
    return <PlaylistModel>[];
  }

  List<PlaylistModel> _parseYouTubeMusicPlaylists(Map<String, dynamic> data) {
    final List<PlaylistModel> playlists = <PlaylistModel>[];
    try {
      final tabs = data['contents']?['tabbedSearchResultsRenderer']?['tabs'];
      if (tabs is! List || tabs.isEmpty) return playlists;
      final sections =
          tabs[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
      if (sections is! List) return playlists;

      for (final s in sections) {
        if (s is! Map<String, dynamic>) continue;
        final shelf = s['musicShelfRenderer'];
        if (shelf is! Map<String, dynamic>) continue;
        final contents = shelf['contents'];
        if (contents is! List) continue;

        for (final item in contents) {
          if (item is! Map<String, dynamic>) continue;
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer is! Map<String, dynamic>) continue;

          final cols = renderer['flexColumns'];
          if (cols is! List || cols.isEmpty) continue;

          // Title
          final col0 = cols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
          final title = (col0 is List && col0.isNotEmpty)
              ? (col0[0]['text'] ?? '').toString()
              : '';
          if (title.isEmpty) continue;

          // Subtitle / Author
          String subtitle = '';
          if (cols.length > 1) {
            final col1 = cols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
            if (col1 is List) {
              subtitle = col1
                  .map((r) => (r is Map ? r['text'] ?? '' : '').toString())
                  .where((t) => t.trim().isNotEmpty && t.trim() != '•')
                  .join(' • ');
            }
          }

          // BrowseId
          String browseId = (renderer['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '')
              .toString();
          if (browseId.isEmpty && col0 is List && col0.isNotEmpty) {
            browseId = (col0[0]?['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '')
                .toString();
          }
          if (browseId.isEmpty) continue;

          // Thumbnail
          String thumb = '';
          final thumbs =
              renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
          if (thumbs is List && thumbs.isNotEmpty) {
            thumb = (thumbs.last['url'] ?? '').toString();
          }

          playlists.add(
            PlaylistModel(
              id: browseId,
              name: title,
              author: subtitle.isNotEmpty ? subtitle : null,
              customThumbnailUrl: thumb.isNotEmpty ? thumb : null,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[InnerTube] Error parsing playlists: $e');
    }
    return playlists;
  }

  /// Fetches playlist details and tracks by YouTube Music [browseId].
  Future<PlaylistModel?> getPlaylistDetails(String browseId) async {
    final effectiveBrowseId =
        browseId.startsWith('VL') ? browseId : 'VL$browseId';
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'context': <String, dynamic>{
          'client': <String, dynamic>{
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20230522.01.00',
            'hl': 'en',
            'gl': 'IN',
          },
        },
        'browseId': effectiveBrowseId,
      };

      final response = await http
          .post(
            Uri.parse('https://music.youtube.com/youtubei/v1/browse'),
            headers: _ytMusicHeaders,
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return _parsePlaylistBrowse(effectiveBrowseId, decoded);
        }
      }
    } catch (e) {
      debugPrint('[InnerTube] Fetch playlist details error: $e');
    }
    return null;
  }

  PlaylistModel? _parsePlaylistBrowse(
    String browseId,
    Map<String, dynamic> data,
  ) {
    try {
      String pName = 'Playlist';
      String pThumb = '';
      String pAuthor = '';

      final contents = data['contents'];
      if (contents is! Map<String, dynamic>) return null;

      final twoCol = contents['twoColumnBrowseResultsRenderer'];
      final singleCol = contents['singleColumnBrowseResultsRenderer'];

      final List<Map<String, dynamic>> shelves = <Map<String, dynamic>>[];

      if (twoCol is Map<String, dynamic>) {
        final sec =
            twoCol['secondaryContents']?['sectionListRenderer']?['contents'];
        if (sec is List) {
          for (final s in sec) {
            if (s is Map<String, dynamic> &&
                s['musicPlaylistShelfRenderer'] is Map<String, dynamic>) {
              shelves.add(s['musicPlaylistShelfRenderer']);
            }
          }
        }
        final tabContent =
            twoCol['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
        if (tabContent is List && tabContent.isNotEmpty) {
          for (final h in tabContent) {
            if (h is! Map<String, dynamic>) continue;
            final head = h['musicResponsiveHeaderRenderer'] ??
                h['musicDetailHeaderRenderer'];
            if (head is Map<String, dynamic>) {
              final titleRuns = head['title']?['runs'];
              if (titleRuns is List && titleRuns.isNotEmpty) {
                pName = (titleRuns[0]['text'] ?? pName).toString();
              }
              final thumbs = head['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
              if (thumbs is List && thumbs.isNotEmpty) {
                pThumb = (thumbs.last['url'] ?? '').toString();
              }
              final subRuns = head['subtitle']?['runs'];
              if (subRuns is List) {
                pAuthor = subRuns
                    .map((r) => (r is Map ? r['text'] ?? '' : '').toString())
                    .where((t) => t.trim().isNotEmpty && t.trim() != '•')
                    .join(' • ');
              }
              break;
            }
          }
        }
      } else if (singleCol is Map<String, dynamic>) {
        final sec = singleCol['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
        if (sec is List) {
          for (final s in sec) {
            if (s is Map<String, dynamic> &&
                s['musicPlaylistShelfRenderer'] is Map<String, dynamic>) {
              shelves.add(s['musicPlaylistShelfRenderer']);
            }
          }
        }
        final header = data['header'];
        if (header is Map<String, dynamic>) {
          final head = header['musicResponsiveHeaderRenderer'] ??
              header['musicDetailHeaderRenderer'];
          if (head is Map<String, dynamic>) {
            final titleRuns = head['title']?['runs'];
            if (titleRuns is List && titleRuns.isNotEmpty) {
              pName = (titleRuns[0]['text'] ?? pName).toString();
            }
            final thumbs = head['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
            if (thumbs is List && thumbs.isNotEmpty) {
              pThumb = (thumbs.last['url'] ?? '').toString();
            }
            final subRuns = head['subtitle']?['runs'];
            if (subRuns is List) {
              pAuthor = subRuns
                  .map((r) => (r is Map ? r['text'] ?? '' : '').toString())
                  .where((t) => t.trim().isNotEmpty && t.trim() != '•')
                  .join(' • ');
            }
          }
        }
      }

      final List<SongModel> songs = <SongModel>[];
      final Set<String> seenIds = <String>{};

      for (final shelf in shelves) {
        final items = shelf['contents'];
        if (items is! List) continue;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final r = item['musicResponsiveListItemRenderer'];
          if (r is! Map<String, dynamic>) continue;

          final cols = r['flexColumns'];
          if (cols is! List || cols.isEmpty) continue;

          // VideoId
          String vid = (r['playlistItemData']?['videoId'] ?? '').toString();
          if (vid.isEmpty) {
            final overlay = r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint'];
            if (overlay is Map<String, dynamic>) {
              vid = (overlay['videoId'] ?? '').toString();
            }
          }
          if (vid.isEmpty || seenIds.contains(vid)) continue;

          // Title
          final col0 = cols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
          final songTitle = (col0 is List && col0.isNotEmpty)
              ? (col0[0]['text'] ?? '').toString()
              : '';
          if (songTitle.isEmpty) continue;

          // Artist
          String songArtist = 'Unknown Artist';
          if (cols.length > 1) {
            final col1 = cols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
            if (col1 is List && col1.isNotEmpty) {
              songArtist = (col1[0]['text'] ?? songArtist).toString();
            }
          }

          // Duration
          String songDur = '--:--';
          if (cols.length >= 3) {
            final col2 = cols[2]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
            if (col2 is List && col2.isNotEmpty) {
              final val = (col2[0]['text'] ?? '').toString();
              if (val.contains(':')) {
                songDur = val;
              }
            }
          }

          // Thumbnail
          String songThumb = pThumb;
          final thumbs = r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
          if (thumbs is List && thumbs.isNotEmpty) {
            songThumb = (thumbs.last['url'] ?? songThumb).toString();
          }

          songs.add(
            SongModel(
              id: vid,
              title: songTitle,
              artist: songArtist,
              duration: songDur,
              thumbnailUrl: songThumb,
            ),
          );
          seenIds.add(vid);
        }
      }

      return PlaylistModel(
        id: browseId,
        name: pName,
        author: pAuthor.isNotEmpty ? pAuthor : null,
        customThumbnailUrl: pThumb.isNotEmpty ? pThumb : null,
        createdAt: DateTime.now(),
        songs: songs,
      );
    } catch (e) {
      debugPrint('[InnerTube] Error parsing browse playlist: $e');
      return null;
    }
  }

  /// Returns the query string for a specific language and pagination index.
  String _getQueryForLanguagePage(String language, int page) {
    final langKey = language.toLowerCase();
    switch (langKey) {
      case 'hindi':
        switch (page) {
          case 0:
            return 'Trending Hindi Songs';
          case 1:
            return 'Top Bollywood Hits';
          case 2:
            return 'Arijit Singh Hits';
          case 3:
            return 'Romantic Hindi Songs';
          case 4:
            return 'Party Dance Hindi';
          case 5:
            return 'Indie Hindi Pop';
          default:
            return 'Hindi Songs page $page';
        }

      case 'english':
        switch (page) {
          case 0:
            return 'Top Global Pop Hits';
          case 1:
            return 'Billboard Hot 100';
          case 2:
            return 'Viral English Songs';
          case 3:
            return 'Top Hip Hop Hits';
          case 4:
            return 'Indie Pop Acoustic';
          default:
            return 'English hits page $page';
        }

      case 'punjabi':
        switch (page) {
          case 0:
            return 'Top Punjabi Hits';
          case 1:
            return 'Diljit Dosanjh Karan Aujla';
          case 2:
            return 'Punjabi Romantic Hits';
          case 3:
            return 'Punjabi Bhangra Beats';
          default:
            return 'Punjabi hits page $page';
        }

      case 'haryanvi':
        switch (page) {
          case 0:
            return 'Top Haryanvi Hits';
          case 1:
            return 'Renuka Panwar Sapna Choudhary';
          case 2:
            return 'Haryanvi DJ Dance';
          default:
            return 'Haryanvi hits page $page';
        }

      default:
        return '$language Songs page $page';
    }
  }

  /// Fetches top official hits for the specified language (initial page).
  Future<List<SongModel>> getByLanguage(
    String language, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = language.toLowerCase();
    if (!forceRefresh &&
        _cachedGenreResults.containsKey(cacheKey) &&
        _cachedGenreResults[cacheKey]!.length >= 10) {
      return _cachedGenreResults[cacheKey]!;
    }

    final initialQuery = _getQueryForLanguagePage(language, 0);
    final initialTracks =
        await _postSearch(initialQuery, languageKey: cacheKey);

    final List<SongModel> dynamicTracks = <SongModel>[];
    final Set<String> existingIds = <String>{};
    final Set<String> existingFingerprints = <String>{};

    for (final track in initialTracks) {
      final fp = normalizeFingerprint(track.title);
      if (!existingIds.contains(track.id) &&
          (fp.isEmpty || !existingFingerprints.contains(fp))) {
        dynamicTracks.add(track);
        existingIds.add(track.id);
        if (fp.isNotEmpty) {
          existingFingerprints.add(fp);
        }
      }
    }

    /// If initial query yields fewer than 12 tracks, supplement with secondary query.
    if (dynamicTracks.length < 12) {
      final secondaryQuery = _getQueryForLanguagePage(language, 1);
      final secondaryBatch =
          await _postSearch(secondaryQuery, languageKey: cacheKey);
      for (final track in secondaryBatch) {
        final fp = normalizeFingerprint(track.title);
        if (!existingIds.contains(track.id) &&
            (fp.isEmpty || !existingFingerprints.contains(fp))) {
          dynamicTracks.add(track);
          existingIds.add(track.id);
          if (fp.isNotEmpty) {
            existingFingerprints.add(fp);
          }
        }
      }
    }

    if (dynamicTracks.isNotEmpty) {
      _cachedGenreResults[cacheKey] = dynamicTracks;
    }

    return dynamicTracks;
  }

  /// Fetches subsequent pages for infinite scrolling on the home feed.
  /// Combines continuation tokens with diverse categorical query pools to guarantee seamless endless loading.
  Future<List<SongModel>> fetchMoreTracks(String language, int page) async {
    final cacheKey = language.toLowerCase();
    final continuation = _continuationTokens[cacheKey];

    List<SongModel> newTracks = <SongModel>[];

    /// Try continuation token first if available.
    if (continuation != null && continuation.isNotEmpty) {
      newTracks = await _postSearch(
        '',
        continuationToken: continuation,
        languageKey: cacheKey,
      );
    }

    /// Fall back to sequential diversified query pool if continuation returns empty.
    if (newTracks.isEmpty) {
      final query = _getQueryForLanguagePage(language, page);
      newTracks = await _postSearch(query, languageKey: cacheKey);
    }

    /// Deduplicate newly fetched tracks against existing tracks in the cache.
    final existingTracks = _cachedGenreResults[cacheKey] ?? <SongModel>[];
    final existingIds = existingTracks.map((s) => s.id).toSet();
    final existingFingerprints = existingTracks
        .map((s) => normalizeFingerprint(s.title))
        .toSet();

    final uniqueNewTracks = newTracks.where((t) {
      if (existingIds.contains(t.id)) return false;
      final fp = normalizeFingerprint(t.title);
      if (fp.isNotEmpty && existingFingerprints.contains(fp)) return false;
      return true;
    }).toList();

    if (uniqueNewTracks.isNotEmpty) {
      existingTracks.addAll(uniqueNewTracks);
      _cachedGenreResults[cacheKey] = existingTracks;
    }

    return uniqueNewTracks;
  }

  /// Fetches top trending hits across popular charts.
  Future<List<SongModel>> getTrending({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTrending.isNotEmpty) {
      return _cachedTrending;
    }

    final tracks = await getByLanguage('Hindi', forceRefresh: forceRefresh);
    if (tracks.isNotEmpty) {
      _cachedTrending = tracks;
    }
    return _cachedTrending;
  }

  /// Backward compatible mood helper delegating to getByLanguage.
  Future<List<SongModel>> getByMood(String mood) => getByLanguage(mood);

  /// Fetches official YouTube Music recommendations and radio queue relative to the given [videoId].
  Future<List<SongModel>> getWatchNextRecommendations(String videoId) async {
    if (videoId.isEmpty) return <SongModel>[];

    try {
      final payload = json.encode(<String, dynamic>{
        'context': <String, dynamic>{
          'client': <String, dynamic>{
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20230522.01.00',
            'hl': 'en',
            'gl': 'IN',
          },
        },
        'videoId': videoId,
        'playlistId': 'RDAMVM$videoId',
      });

      final response = await http
          .post(
            Uri.parse(_ytMusicNextEndpoint),
            headers: _ytMusicHeaders,
            body: payload,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return <SongModel>[];
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return <SongModel>[];
      }

      final queueContents = decoded['contents']
          ?['singleColumnMusicWatchNextResultsRenderer']
          ?['tabbedRenderer']
          ?['watchNextTabbedResultsRenderer']
          ?['tabs']?[0]?['tabRenderer']
          ?['content']?['musicQueueRenderer']
          ?['content']?['playlistPanelRenderer']?['contents'];

      if (queueContents is! List) {
        return <SongModel>[];
      }

      final List<SongModel> similarSongs = <SongModel>[];
      final Set<String> seenIds = <String>{};
      final Set<String> seenFingerprints = <String>{};

      for (final item in queueContents) {
        if (item is! Map<String, dynamic>) continue;
        final ppv = item['playlistPanelVideoRenderer'];
        if (ppv is! Map<String, dynamic>) continue;

        final song = SongModel.fromPlaylistPanel(ppv);
        if (song.id.isEmpty || song.id == videoId) continue;
        if (!_isValidMusicTrack(song)) continue;

        final parsedDur = song.parsedDuration;
        if (parsedDur != null && parsedDur.inMinutes > 15) {
          continue;
        }

        final fp = SongModel.normalizeFingerprint(song.title);
        if (!seenIds.contains(song.id) &&
            (fp.isEmpty || !seenFingerprints.contains(fp))) {
          similarSongs.add(song);
          seenIds.add(song.id);
          if (fp.isNotEmpty) {
            seenFingerprints.add(fp);
          }
        }
      }

      return similarSongs;
    } catch (_) {
      return <SongModel>[];
    }
  }

  /// Backward compatible alias for autoplay and queue generation.
  Future<List<SongModel>> getSimilarSongs(String videoId) =>
      getWatchNextRecommendations(videoId);

  /// Filters out non-music uploads, reaction videos, and amateur recordings.
  static bool _isValidMusicTrack(SongModel track) {
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();

    const excludedKeywords = <String>[
      'full movie',
      'reaction',
      'interview',
      'vlog',
      'unboxing',
      'tutorial',
      'guitar lesson',
      'piano tutorial',
      'parody',
      'roast',
      'review',
      'podcast',
      'live stream',
      'comedy video',
      'behind the scenes',
      'making of',
    ];

    for (final keyword in excludedKeywords) {
      if (title.contains(keyword) || artist.contains(keyword)) {
        return false;
      }
    }

    if (track.duration != '--:--' && track.duration.isNotEmpty) {
      final parts = track.duration.split(':');
      if (parts.length > 2) {
        return false;
      }
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        if (minutes >= 15) {
          return false;
        }
        if (minutes == 0 && seconds < 20) {
          return false;
        }
      }
    }

    return true;
  }
}
