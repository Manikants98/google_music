import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../audio/stream_extractor.dart';
import '../../models/song_model.dart';

/// Persistent service managing offline audio file downloads and playback storage.
class OfflineDownloadService extends ChangeNotifier {
  /// In-memory cache of downloaded songs indexed by song ID.
  final Map<String, SongModel> _downloadedSongs = <String, SongModel>{};

  /// In-memory map of active download progress percentage (0.0 to 1.0).
  final Map<String, double> _downloadProgress = <String, double>{};

  /// Set of active download IDs currently being written to disk.
  final Set<String> _activeDownloads = <String>{};

  /// In-memory map of active songs currently being downloaded.
  final Map<String, SongModel> _activeDownloadSongs = <String, SongModel>{};

  /// Active HTTP clients indexed by song ID for cancellation support.
  final Map<String, http.Client> _activeClients = <String, http.Client>{};

  /// Set of cancelled download song IDs.
  final Set<String> _cancelledDownloads = <String>{};

  /// Callback when a download's progress updates (song, percentage 0-100, isComplete).
  void Function(SongModel song, int progressPercent, bool isComplete)?
      onDownloadProgressUpdated;

  /// Callback when all active downloads have concluded.
  void Function()? onAllDownloadsFinished;

  /// Callback when a download is explicitly cancelled by user.
  void Function(SongModel song)? onDownloadCancelled;

  /// The root directory where offline audio files are stored.
  Directory? _storageDir;

  /// The metadata file persisting the registry of downloaded songs.
  File? _metadataFile;

  /// Total storage consumed by offline audio in bytes.
  int _totalBytesUsed = 0;

  /// Gets list of all songs saved for offline playback.
  List<SongModel> get downloadedSongs => _downloadedSongs.values.toList();

  /// Gets list of all songs currently actively downloading.
  List<SongModel> get activeDownloadSongs =>
      _activeDownloadSongs.values.toList();

  /// Gets total storage bytes used by downloaded tracks.
  int get totalBytesUsed => _totalBytesUsed;

  /// Returns human-readable storage string (e.g. '14.2 MB' or '0 B').
  String get formattedStorageUsed {
    if (_totalBytesUsed <= 0) return '0 B';
    if (_totalBytesUsed < 1024 * 1024) {
      final kb = (_totalBytesUsed / 1024).toStringAsFixed(1);
      return '$kb KB';
    }
    final mb = (_totalBytesUsed / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB';
  }

  /// Initializes the storage directory and loads persisted download metadata.
  Future<void> initialize() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _storageDir = Directory('${docDir.path}/offline_music');
      if (!await _storageDir!.exists()) {
        await _storageDir!.create(recursive: true);
      }

      _metadataFile = File('${_storageDir!.path}/downloads_registry.json');
      await _loadPersistedMetadata();
      await _recalculateStorageUsage();
    } catch (e) {
      debugPrint('[OfflineDownloadService] Initialization error: $e');
    }
  }

  /// Checks if a song is fully downloaded and available on disk.
  bool isDownloaded(String songId) {
    if (!_downloadedSongs.containsKey(songId)) return false;
    final path = getLocalAudioPath(songId);
    if (path == null) return false;
    return File(path).existsSync();
  }

  /// Checks if a song is actively downloading right now.
  bool isDownloading(String songId) {
    return _activeDownloads.contains(songId);
  }

  /// Retrieves download progress fraction for a song (0.0 to 1.0), or null if not downloading.
  double? getDownloadProgress(String songId) {
    return _downloadProgress[songId];
  }

  /// Retrieves active download song model by song ID.
  SongModel? getActiveDownloadSong(String songId) {
    return _activeDownloadSongs[songId];
  }

  /// Returns absolute filesystem path to the downloaded audio file, or null if uninitialized.
  String? getLocalAudioPath(String songId) {
    if (_storageDir == null) return null;
    return '${_storageDir!.path}/$songId.audio';
  }

  /// Downloads an audio stream for [song] and registers it for offline playback.
  Future<bool> downloadSong(
    SongModel song,
    AudioStreamExtractor extractor,
  ) async {
    if (isDownloaded(song.id) || isDownloading(song.id)) {
      return true;
    }

    if (_storageDir == null) {
      await initialize();
    }

    _activeDownloads.add(song.id);
    _activeDownloadSongs[song.id] = song;
    _downloadProgress[song.id] = 0.05;
    notifyListeners();
    onDownloadProgressUpdated?.call(song, 5, false);

    final targetPath = getLocalAudioPath(song.id)!;
    final tempPath = '$targetPath.tmp';
    final tempFile = File(tempPath);

    http.Client? client;
    try {
      final candidateUrls = await extractor.getCandidateStreamUrls(song.id);
      if (_cancelledDownloads.contains(song.id)) {
        throw Exception('Download cancelled by user.');
      }
      if (candidateUrls.isEmpty) {
        throw Exception('No stream candidate URLs found for download.');
      }

      String? successfulUrl;
      http.StreamedResponse? response;
      client = http.Client();
      _activeClients[song.id] = client;

      for (final url in candidateUrls) {
        if (_cancelledDownloads.contains(song.id)) {
          throw Exception('Download cancelled by user.');
        }
        try {
          final request = http.Request('GET', Uri.parse(url));
          request.headers.addAll(<String, String>{
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com/',
          });

          final candidateResponse = await client.send(request);
          if (candidateResponse.statusCode == 200) {
            response = candidateResponse;
            successfulUrl = url;
            break;
          }
        } catch (_) {}
      }

      if (response == null || successfulUrl == null) {
        throw Exception('Failed to connect to any audio stream source.');
      }

      final totalBytes = (response.contentLength != null &&
              response.contentLength! > 0)
          ? response.contentLength!
          : ((song.parsedDuration?.inSeconds ?? 210) * 16000);
      var receivedBytes = 0;

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      final sink = tempFile.openWrite();

      var lastProgressUpdate = DateTime.now();
      var lastNotificationUpdate = DateTime.now();
      var lastNotifiedPercent = 5;

      await for (final chunk in response.stream) {
        if (_cancelledDownloads.contains(song.id)) {
          await sink.close();
          throw Exception('Download cancelled by user.');
        }
        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now();
        if (totalBytes > 0 &&
            now.difference(lastProgressUpdate).inMilliseconds > 100) {
          lastProgressUpdate = now;
          final fraction = (receivedBytes / totalBytes).clamp(0.05, 0.98);
          _downloadProgress[song.id] = fraction;
          notifyListeners();

          final percent = (fraction * 100).toInt();
          if (percent != lastNotifiedPercent &&
              now.difference(lastNotificationUpdate).inMilliseconds > 350) {
            lastNotificationUpdate = now;
            lastNotifiedPercent = percent;
            onDownloadProgressUpdated?.call(song, percent, false);
          }
        }
      }

      await sink.flush();
      await sink.close();

      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetPath);

      _downloadedSongs[song.id] = song;
      await _persistMetadata();
      await _recalculateStorageUsage();

      _downloadProgress.remove(song.id);
      _activeDownloads.remove(song.id);
      _activeDownloadSongs.remove(song.id);
      _activeClients.remove(song.id);
      _cancelledDownloads.remove(song.id);
      notifyListeners();
      onDownloadProgressUpdated?.call(song, 100, true);
      if (_activeDownloads.isEmpty) {
        onAllDownloadsFinished?.call();
      }
      return true;
    } catch (err) {
      debugPrint('[OfflineDownloadService] Download failed for ${song.id}: $err');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      _downloadProgress.remove(song.id);
      _activeDownloads.remove(song.id);
      _activeDownloadSongs.remove(song.id);
      _activeClients.remove(song.id);
      _cancelledDownloads.remove(song.id);
      notifyListeners();
      if (_activeDownloads.isEmpty) {
        onAllDownloadsFinished?.call();
      }
      return false;
    } finally {
      client?.close();
      _activeClients.remove(song.id);
    }
  }

  /// Cancels an in-progress download for [songId] and cleans up temporary files.
  void cancelDownload(String songId) {
    if (!_activeDownloads.contains(songId)) return;
    _cancelledDownloads.add(songId);
    try {
      _activeClients[songId]?.close();
    } catch (_) {}
    _activeClients.remove(songId);
    _activeDownloads.remove(songId);
    final song = _activeDownloadSongs.remove(songId);
    _downloadProgress.remove(songId);

    final targetPath = getLocalAudioPath(songId);
    if (targetPath != null) {
      final tempFile = File('$targetPath.tmp');
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
    _cancelledDownloads.remove(songId);
    notifyListeners();
    if (song != null) {
      onDownloadCancelled?.call(song);
    }
    if (_activeDownloads.isEmpty) {
      onAllDownloadsFinished?.call();
    }
  }

  /// Removes downloaded file and registry record for a specific song.
  Future<bool> removeDownload(String songId) async {
    try {
      final path = getLocalAudioPath(songId);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _downloadedSongs.remove(songId);
      _downloadProgress.remove(songId);
      _activeDownloads.remove(songId);
      _activeDownloadSongs.remove(songId);

      await _persistMetadata();
      await _recalculateStorageUsage();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[OfflineDownloadService] Failed to remove download for $songId: $e');
      return false;
    }
  }

  /// Clears all downloaded audio files from device storage.
  Future<void> clearAllDownloads() async {
    try {
      for (final id in _activeDownloads.toList()) {
        cancelDownload(id);
      }

      if (_storageDir != null && await _storageDir!.exists()) {
        final entities = await _storageDir!.list().toList();
        for (final entity in entities) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      _downloadedSongs.clear();
      _downloadProgress.clear();
      _activeDownloads.clear();
      _activeDownloadSongs.clear();
      _totalBytesUsed = 0;

      await _persistMetadata();
      notifyListeners();
    } catch (e) {
      debugPrint('[OfflineDownloadService] Clear all downloads error: $e');
    }
  }

  /// Loads persisted song metadata registry from disk.
  Future<void> _loadPersistedMetadata() async {
    if (_metadataFile == null || !await _metadataFile!.exists()) return;

    try {
      final raw = await _metadataFile!.readAsString();
      if (raw.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        _downloadedSongs.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final song = SongModel.fromMap(item);
            final path = getLocalAudioPath(song.id);
            if (path != null && File(path).existsSync()) {
              _downloadedSongs[song.id] = song;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OfflineDownloadService] Error parsing metadata: $e');
    }
  }

  /// Saves the in-memory registry of downloaded songs to disk atomically to prevent corruption.
  Future<void> _persistMetadata() async {
    if (_metadataFile == null) return;
    try {
      final list = _downloadedSongs.values
          .map((SongModel s) => s.toMap())
          .toList();
      final content = jsonEncode(list);
      final tempFile = File('${_metadataFile!.path}.tmp');
      await tempFile.writeAsString(content, flush: true);
      if (await _metadataFile!.exists()) {
        await _metadataFile!.delete();
      }
      await tempFile.rename(_metadataFile!.path);
    } catch (e) {
      debugPrint('[OfflineDownloadService] Failed to persist metadata: $e');
    }
  }

  /// Calculates total bytes of audio stored on disk.
  Future<void> _recalculateStorageUsage() async {
    if (_storageDir == null || !await _storageDir!.exists()) {
      _totalBytesUsed = 0;
      return;
    }

    try {
      var bytes = 0;
      final entities = await _storageDir!.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.audio')) {
          bytes += await entity.length();
        }
      }
      _totalBytesUsed = bytes;
    } catch (_) {
      _totalBytesUsed = 0;
    }
  }
}
