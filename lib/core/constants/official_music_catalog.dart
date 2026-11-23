import '../../models/song_model.dart';

/// Legacy catalog definition kept for interface compatibility.
/// All songs are now fetched live dynamically from YouTube Music InnerTube.
abstract final class OfficialMusicCatalog {
  /// Empty fallback list indicating dynamic fetching is enforced.
  static const List<SongModel> emptyList = <SongModel>[];

  /// Returns empty list so caller relies exclusively on live network responses.
  static List<SongModel> getSongsForLanguage(String language) => emptyList;
}
