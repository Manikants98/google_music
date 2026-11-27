import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_update_dialog.dart';
import 'app_update_info.dart';

/// Service managing Over-The-Air (OTA) in-app updates sourced from GitHub Releases.
class AppUpdateService {
  /// GitHub repository owner account.
  static const String githubOwner = 'Manikants98';

  /// GitHub repository project name.
  static const String githubRepo = 'google_music';

  /// Active application semantic version name.
  static const String currentAppVersion = '1.0.7-beta.2';

  /// Cached version string initialized from package or fallback.
  static String _cachedVersion = currentAppVersion;

  /// Version tag that user explicitly dismissed with "Later" in the active session.
  static String? _dismissedVersion;

  /// Marks a version as dismissed for automatic prompts during the active session.
  static void dismissVersion(String version) {
    _dismissedVersion = version;
  }

  /// Platform channel communicating with Android native package installer and version metadata.
  static const MethodChannel _channel = MethodChannel(
    'com.mkx.google_music/download_notification',
  );

  /// Retrieves the active version name from Android package manager or cached fallback.
  static Future<String> getAppVersion() async {
    try {
      final String? version = await _channel.invokeMethod<String>(
        'getAppVersion',
      );
      if (version != null && version.isNotEmpty) {
        _cachedVersion = version;
        return version;
      }
    } catch (_) {}
    return _cachedVersion;
  }

  /// Compares two semver strings (e.g. '1.0.1' vs '1.0.0', '1.0.6-beta.1' vs '1.0.5').
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if equal.
  static int compareVersions(String v1, String v2) {
    final clean1 = v1.replaceAll(RegExp(r'^[vV]'), '').split('+').first.trim();
    final clean2 = v2.replaceAll(RegExp(r'^[vV]'), '').split('+').first.trim();

    final base1 = clean1.split('-').first;
    final base2 = clean2.split('-').first;

    final parts1 = base1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = base2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length
        ? parts1.length
        : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }

    if (clean1 != clean2) {
      final isPre1 = clean1.contains('-');
      final isPre2 = clean2.contains('-');
      if (!isPre1 && isPre2) return 1;
      if (isPre1 && !isPre2) return -1;
      return clean1.compareTo(clean2);
    }

    return 0;
  }

  /// Queries the public GitHub Releases API to discover newly published APK versions.
  /// When [includeBeta] is true, queries all releases (including pre-releases/betas).
  /// When [includeBeta] is false, queries only formal latest releases.
  static Future<AppUpdateInfo?> checkForUpdate({
    bool includeBeta = false,
  }) async {
    try {
      final uri = includeBeta
          ? Uri.parse(
              'https://api.github.com/repos/$githubOwner/$githubRepo/releases',
            )
          : Uri.parse(
              'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest',
            );

      final response = await http
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'GoogleMusic-AppUpdater',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      Map<String, dynamic>? releaseData;

      if (includeBeta && decoded is List && decoded.isNotEmpty) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final assets = item['assets'];
            if (assets is List &&
                assets.any(
                  (a) =>
                      a is Map<String, dynamic> &&
                      (a['name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .endsWith('.apk'),
                )) {
              releaseData = item;
              break;
            }
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        releaseData = decoded;
      }

      if (releaseData == null) {
        return null;
      }

      final tagName = (releaseData['tag_name'] ?? '').toString();
      final title = (releaseData['name'] ?? tagName).toString();
      final body =
          (releaseData['body'] ?? 'Performance improvements and bug fixes.')
              .toString();
      final isPrerelease = releaseData['prerelease'] == true ||
          tagName.toLowerCase().contains('beta');
      final rawPublished = releaseData['published_at']?.toString();
      final publishedAt = rawPublished != null
          ? DateTime.tryParse(rawPublished)
          : null;

      final currentVer = await getAppVersion();
      final isNewer = compareVersions(tagName, currentVer) > 0;
      if (!isNewer) {
        return null;
      }

      if (Platform.isIOS) {
        // On iOS, APK packages cannot be installed.
        return null;
      }

      final assets = releaseData['assets'];
      if (assets is! List || assets.isEmpty) {
        return null;
      }

      String? apkDownloadUrl;
      int apkSize = 0;

      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final assetName = (asset['name'] ?? '').toString().toLowerCase();
          if (assetName.endsWith('.apk')) {
            apkDownloadUrl = asset['browser_download_url']?.toString();
            final rawSize = asset['size'];
            if (rawSize is num) {
              apkSize = rawSize.toInt();
            }
            break;
          }
        }
      }

      if (apkDownloadUrl == null || apkDownloadUrl.isEmpty) {
        return null;
      }

      return AppUpdateInfo(
        version: tagName.replaceAll(RegExp(r'^[vV]'), ''),
        title: title,
        changelog: body,
        downloadUrl: apkDownloadUrl,
        fileSizeBytes: apkSize,
        publishedAt: publishedAt,
        isBeta: isPrerelease,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Check update error: $e');
      return null;
    }
  }

  /// Downloads the specified release APK file with progress reporting and initiates native package install.
  static Future<bool> downloadAndInstall({
    required AppUpdateInfo updateInfo,
    required void Function(double progress, int downloadedBytes, int totalBytes)
    onProgress,
  }) async {
    http.Client? client;
    try {
      final cacheDir = await getTemporaryDirectory();
      final updateDir = Directory('${cacheDir.path}/updates');
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }

      final apkFile = File(
        '${updateDir.path}/google_music_${updateInfo.version}.apk',
      );
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      client = http.Client();
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      request.headers['User-Agent'] = 'GoogleMusic-AppUpdater';

      final response = await client.send(request);
      if (response.statusCode != 200) {
        return false;
      }

      final totalBytes = response.contentLength ?? updateInfo.fileSizeBytes;
      var receivedBytes = 0;

      final sink = apkFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(progress, receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      onProgress(1.0, receivedBytes, totalBytes);

      final result = await _channel.invokeMethod<bool>(
        'installApk',
        <String, Object>{'filePath': apkFile.path},
      );

      return result == true;
    } catch (e) {
      debugPrint('[AppUpdateService] Download error: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  /// Initiates update check with UI prompts: silent on app start, or explicit toast on manual check.
  static Future<void> checkAndPrompt(
    BuildContext context, {
    bool manual = false,
    bool includeBeta = false,
  }) async {
    final update = await checkForUpdate(includeBeta: includeBeta);
    if (!context.mounted) return;

    if (update != null) {
      if (!manual && _dismissedVersion == update.version) {
        return;
      }
      AppUpdateDialog.show(context, update);
    } else if (manual) {
      final currentVer = await getAppVersion();
      if (!context.mounted) return;
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          elevation: 8,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: <Widget>[
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Google Music is up to date (v$currentVer)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
