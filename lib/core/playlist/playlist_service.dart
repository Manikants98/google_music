import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/playlist_model.dart';
import '../../models/song_model.dart';

/// Persistent service managing creation, updates, and persistence of custom playlists.
class PlaylistService extends ChangeNotifier {
  /// In-memory cache of custom playlists.
  final List<PlaylistModel> _playlists = <PlaylistModel>[];

  /// File handle where playlists JSON is persisted on disk.
  File? _storageFile;

  /// Gets immutable list of all custom user playlists.
  List<PlaylistModel> get playlists =>
      List<PlaylistModel>.unmodifiable(_playlists);

  /// Initializes playlist service by loading persisted playlists from disk.
  Future<void> initialize() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _storageFile = File('${docDir.path}/user_playlists.json');
      await _loadPersistedPlaylists();
    } catch (e) {
      debugPrint('[PlaylistService] Initialization error: $e');
    }
  }

  /// Finds a specific playlist by its ID.
  PlaylistModel? getPlaylist(String id) {
    try {
      return _playlists.firstWhere((PlaylistModel p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Creates a new custom playlist with the specified [name].
  Future<PlaylistModel> createPlaylist(String name) async {
    final trimmedName = name.trim().isEmpty ? 'My Playlist' : name.trim();
    final newPlaylist = PlaylistModel(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      createdAt: DateTime.now(),
      songs: <SongModel>[],
    );

    _playlists.insert(0, newPlaylist);
    await _persist();
    notifyListeners();
    return newPlaylist;
  }

  /// Deletes a playlist by its [id].
  Future<bool> deletePlaylist(String id) async {
    final index = _playlists.indexWhere((PlaylistModel p) => p.id == id);
    if (index == -1) return false;

    _playlists.removeAt(index);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Renames an existing playlist.
  Future<bool> renamePlaylist(String id, String newName) async {
    final index = _playlists.indexWhere((PlaylistModel p) => p.id == id);
    if (index == -1) return false;

    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    _playlists[index] = _playlists[index].copyWith(name: trimmed);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Adds a song to an existing playlist.
  /// Returns `true` if added, or `false` if track is already in playlist or not found.
  Future<bool> addSongToPlaylist(String playlistId, SongModel song) async {
    final index = _playlists.indexWhere((PlaylistModel p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    final alreadyExists = playlist.songs.any((SongModel s) => s.id == song.id);
    if (alreadyExists) return false;

    final updatedSongs = List<SongModel>.from(playlist.songs)..add(song);
    _playlists[index] = playlist.copyWith(songs: updatedSongs);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Removes a song from an existing playlist.
  Future<bool> removeSongFromPlaylist(
    String playlistId,
    String songId,
  ) async {
    final index = _playlists.indexWhere((PlaylistModel p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    final updatedSongs =
        playlist.songs.where((SongModel s) => s.id != songId).toList();

    _playlists[index] = playlist.copyWith(songs: updatedSongs);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Checks whether a song is already present in a given playlist.
  bool isSongInPlaylist(String playlistId, String songId) {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) return false;
    return playlist.songs.any((SongModel s) => s.id == songId);
  }

  /// Reads playlists from disk into memory.
  Future<void> _loadPersistedPlaylists() async {
    if (_storageFile == null || !await _storageFile!.exists()) return;

    try {
      final content = await _storageFile!.readAsString();
      if (content.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(content);
      if (decoded is List) {
        _playlists.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _playlists.add(PlaylistModel.fromMap(item));
          }
        }
      }
    } catch (e) {
      debugPrint('[PlaylistService] Failed to load playlists: $e');
    }
  }

  /// Writes playlists to disk atomically in JSON format to prevent corruption on sudden termination.
  Future<void> _persist() async {
    if (_storageFile == null) return;

    try {
      final serialized =
          _playlists.map((PlaylistModel p) => p.toMap()).toList();
      final content = jsonEncode(serialized);
      final tempFile = File('${_storageFile!.path}.tmp');
      await tempFile.writeAsString(content, flush: true);
      if (await _storageFile!.exists()) {
        await _storageFile!.delete();
      }
      await tempFile.rename(_storageFile!.path);
    } catch (e) {
      debugPrint('[PlaylistService] Failed to persist playlists: $e');
    }
  }
}
