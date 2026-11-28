import 'song_model.dart';

/// Domain model representing a user-curated or remote music playlist.
class PlaylistModel {
  /// Unique identifier for the playlist (e.g. 'pl_123' or 'VLPL...').
  final String id;

  /// User-defined or remote playlist display name.
  final String name;

  /// Creator or subtitle description (e.g. 'YouTube Music' or 'Anuv Jain').
  final String? author;

  /// Custom or remote cover art URL if available.
  final String? customThumbnailUrl;

  /// Timestamp when playlist was created or imported.
  final DateTime createdAt;

  /// Ordered list of tracks contained in this playlist.
  final List<SongModel> songs;

  /// Creates a playlist instance.
  PlaylistModel({
    required this.id,
    required this.name,
    this.author,
    this.customThumbnailUrl,
    required this.createdAt,
    List<SongModel>? songs,
  }) : songs = songs ?? <SongModel>[];

  /// Resolves thumbnail URL from custom URL first, then from the first track in playlist, or null if empty.
  String? get thumbnailUrl =>
      customThumbnailUrl ?? (songs.isNotEmpty ? songs.first.thumbnailUrl : null);

  /// Returns total count of tracks.
  int get trackCount => songs.length;

  /// Serializes playlist to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (author != null) 'author': author,
      if (customThumbnailUrl != null) 'customThumbnailUrl': customThumbnailUrl,
      'createdAt': createdAt.toIso8601String(),
      'songs': songs.map((SongModel s) => s.toMap()).toList(),
    };
  }

  /// Deserializes playlist from a JSON map.
  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    final rawSongs = map['songs'];
    final List<SongModel> loadedSongs = <SongModel>[];

    if (rawSongs is List) {
      for (final item in rawSongs) {
        if (item is Map<String, dynamic>) {
          loadedSongs.add(SongModel.fromMap(item));
        }
      }
    }

    return PlaylistModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Untitled Playlist').toString(),
      author: map['author'] as String?,
      customThumbnailUrl: map['customThumbnailUrl'] as String?,
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      songs: loadedSongs,
    );
  }

  /// Creates a shallow copy of the playlist with optional updated fields.
  PlaylistModel copyWith({
    String? id,
    String? name,
    String? author,
    String? customThumbnailUrl,
    DateTime? createdAt,
    List<SongModel>? songs,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      customThumbnailUrl: customThumbnailUrl ?? this.customThumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      songs: songs ?? List<SongModel>.from(this.songs),
    );
  }
}
