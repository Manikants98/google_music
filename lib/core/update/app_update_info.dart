/// Model representing an available application update released on GitHub.
class AppUpdateInfo {
  /// Semantic version string of the release (e.g. '1.0.1').
  final String version;

  /// Display headline or release title.
  final String title;

  /// Changelog or release notes in markdown format.
  final String changelog;

  /// Direct browser download URL for the .apk asset file.
  final String downloadUrl;

  /// File size of the APK asset in bytes.
  final int fileSizeBytes;

  /// Timestamp when release was published.
  final DateTime? publishedAt;

  /// Creates an application update information container.
  const AppUpdateInfo({
    required this.version,
    required this.title,
    required this.changelog,
    required this.downloadUrl,
    required this.fileSizeBytes,
    this.publishedAt,
  });

  /// Formatted file size string (e.g. '58.2 MB').
  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 B';
    if (fileSizeBytes < 1024 * 1024) {
      final kb = (fileSizeBytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    }
    final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB';
  }
}
