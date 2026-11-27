import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../audio/music_player_controller.dart';
import 'app_update_info.dart';
import 'app_update_service.dart';

/// Modal dialog presenting application update details and handling OTA package download.
class AppUpdateDialog extends StatefulWidget {
  /// Information container for the available update.
  final AppUpdateInfo updateInfo;

  /// Creates an application update dialog.
  const AppUpdateDialog({super.key, required this.updateInfo});

  /// Displays the update modal dialog over the active navigation context.
  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppUpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  /// Initiates download of the new APK package with real-time byte progress reporting.
  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = widget.updateInfo.fileSizeBytes;
    });

    final success = await AppUpdateService.downloadAndInstall(
      updateInfo: widget.updateInfo,
      onProgress: (progressValue, downloaded, total) {
        if (mounted) {
          setState(() {
            _progress = progressValue;
            _downloadedBytes = downloaded;
            _totalBytes = total;
          });
        }
      },
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Installation could not start. Please retry.';
      });
    }
  }

  /// Formats byte numbers into human-readable megabyte strings.
  String _formatMb(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();
    final accent = controller.getLegibleAccentColor(
      theme.brightness == Brightness.dark,
    );

    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isDownloading,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Update Available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v${widget.updateInfo.version}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.updateInfo.isBeta) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'BETA',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        widget.updateInfo.formattedFileSize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_isDownloading) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _progress >= 1.0
                      ? 'Opening package installer...'
                      : 'Downloading update (${(_progress * 100).toInt()}%)...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      _formatMb(_downloadedBytes),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatMb(_totalBytes),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ] else ...<Widget>[
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline_rounded,
                          color: colorScheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  widget.updateInfo.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: _buildChangelogContent(
                      rawChangelog: widget.updateInfo.changelog,
                      theme: theme,
                      colorScheme: colorScheme,
                      accent: accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          if (!_isDownloading) ...<Widget>[
            TextButton(
              onPressed: () {
                AppUpdateService.dismissVersion(widget.updateInfo.version);
                Navigator.of(context).pop();
              },
              child: Text(
                'Later',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: accent.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _startDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(_errorMessage != null ? 'Retry' : 'Update Now'),
            ),
          ],
        ],
      ),
    );
  }

  /// Formats raw markdown changelog into styled headings and bullet points.
  Widget _buildChangelogContent({
    required String rawChangelog,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required Color accent,
  }) {
    if (rawChangelog.trim().isEmpty) {
      return Text(
        'Bug fixes and performance enhancements.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      );
    }

    final lines = rawChangelog.split(RegExp(r'\r?\n'));
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      /// Check for heading (#, ##, ###)
      final headerMatch = RegExp(r'^(#{1,6})\s*(.*)$').firstMatch(trimmed);
      if (headerMatch != null) {
        final headingText = headerMatch.group(2) ?? '';
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: widgets.isNotEmpty ? 10 : 0,
              bottom: 4,
            ),
            child: Text(
              headingText,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                fontSize: 13,
                letterSpacing: -0.1,
              ),
            ),
          ),
        );
        continue;
      }

      /// Check for bullet points (-, *, +, •)
      final bulletMatch = RegExp(r'^[-*+•]\s*(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        final bulletText = bulletMatch.group(1) ?? '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: _parseInlineFormatting(
                        bulletText,
                        colorScheme,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      /// Regular paragraph text
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(
              children: _parseInlineFormatting(
                trimmed,
                colorScheme,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  /// Parses inline bold syntax (**text**) into stylized TextSpan items.
  List<TextSpan> _parseInlineFormatting(
    String text,
    ColorScheme colorScheme,
  ) {
    final spans = <TextSpan>[];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      final isBold = i.isOdd;
      spans.add(
        TextSpan(
          text: part,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: isBold ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }

    return spans;
  }
}
