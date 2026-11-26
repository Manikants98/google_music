import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';

/// Modal bottom sheet presenting sleep timer presets and real-time countdown controls.
class SleepTimerSheet extends StatelessWidget {
  /// Creates a sleep timer modal sheet.
  const SleepTimerSheet({super.key});

  /// Displays the sleep timer bottom sheet modal.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SleepTimerSheet(),
    );
  }

  /// Formats remaining duration into MM:SS or HH:MM:SS.
  static String formatRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      final mStr = minutes.toString().padLeft(2, '0');
      final sStr = seconds.toString().padLeft(2, '0');
      return '$hours:$mStr:$sStr';
    }
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  /// Formats target time into 12-hour AM/PM format (e.g. "11:45 PM").
  static String formatStopTime(DateTime target) {
    final hour = target.hour == 0
        ? 12
        : (target.hour > 12 ? target.hour - 12 : target.hour);
    final minute = target.minute.toString().padLeft(2, '0');
    final ampm = target.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();
    final accent = controller.dynamicAccentColor;

    final isActive = controller.isSleepTimerActive;
    final isEndOfTrack = controller.isSleepTimerEndOfTrack;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 10, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Sleep Timer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Audio will fade out and pause automatically',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 28,
                      ),
                      color: colorScheme.onSurfaceVariant,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 8),
              if (isActive) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.75,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.timer_rounded,
                            color: accent,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (isEndOfTrack)
                                Text(
                                  'Stopping at end of track',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                )
                              else
                                ValueListenableBuilder<Duration?>(
                                  valueListenable:
                                      controller.sleepTimerRemainingNotifier,
                                  builder: (context, remaining, child) {
                                    if (remaining == null ||
                                        remaining <= Duration.zero) {
                                      return Text(
                                        'Stopping soon...',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                      );
                                    }
                                    return Text(
                                      'Stopping in ${formatRemaining(remaining)}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: accent,
                                          ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 1),
                              Text(
                                isEndOfTrack
                                    ? 'Current song will complete then pause'
                                    : (controller.sleepTimerTarget != null
                                          ? 'Scheduled stop at ${formatStopTime(controller.sleepTimerTarget!)}'
                                          : 'Fading out before stopping'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.errorContainer
                                .withValues(alpha: 0.6),
                            foregroundColor: colorScheme.error,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            controller.cancelSleepTimer();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Sleep timer turned off'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Turn Off',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: <Widget>[
                    _buildOptionRow(
                      context: context,
                      icon: Icons.access_time_rounded,
                      title: '5 minutes',
                      duration: const Duration(minutes: 5),
                      controller: controller,
                      theme: theme,
                      colorScheme: colorScheme,
                      accent: accent,
                    ),
                    _buildOptionRow(
                      context: context,
                      icon: Icons.access_time_rounded,
                      title: '15 minutes',
                      duration: const Duration(minutes: 15),
                      controller: controller,
                      theme: theme,
                      colorScheme: colorScheme,
                      accent: accent,
                    ),
                    _buildOptionRow(
                      context: context,
                      icon: Icons.access_time_rounded,
                      title: '30 minutes',
                      duration: const Duration(minutes: 30),
                      controller: controller,
                      theme: theme,
                      colorScheme: colorScheme,
                      accent: accent,
                    ),
                    _buildOptionRow(
                      context: context,
                      icon: Icons.access_time_rounded,
                      title: '45 minutes',
                      duration: const Duration(minutes: 45),
                      controller: controller,
                      theme: theme,
                      colorScheme: colorScheme,
                      accent: accent,
                    ),
                    _buildOptionRow(
                      context: context,
                      icon: Icons.access_time_rounded,
                      title: '1 hour',
                      duration: const Duration(hours: 1),
                      controller: controller,
                      theme: theme,
                      colorScheme: colorScheme,
                      accent: accent,
                    ),
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        controller.setSleepTimerEndOfTrack();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Sleep timer set to stop at end of track',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.skip_next_rounded,
                              size: 20,
                              color: isEndOfTrack
                                  ? accent
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'End of track',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isEndOfTrack
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: -0.1,
                                      color: isEndOfTrack
                                          ? accent
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Playback stops when current track finishes',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isEndOfTrack)
                              Icon(
                                Icons.check_rounded,
                                color: accent,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showCustomDurationDialog(
                        context,
                        controller,
                        accent,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Custom duration...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: -0.1,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Choose custom minutes up to 4 hours',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a clean selectable preset duration row with projected stop time.
  Widget _buildOptionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Duration duration,
    required MusicPlayerController controller,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required Color accent,
  }) {
    final targetTime = DateTime.now().add(duration);
    final stopTimeStr = formatStopTime(targetTime);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        controller.setSleepTimer(duration);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sleep timer set for $title (stops at $stopTimeStr)'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.1,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Stops around $stopTimeStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
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

  /// Shows custom duration input dialog.
  void _showCustomDurationDialog(
    BuildContext context,
    MusicPlayerController controller,
    Color accent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    int selectedMinutes = 20;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final targetTime = DateTime.now().add(
              Duration(minutes: selectedMinutes),
            );
            final stopTimeStr = formatStopTime(targetTime);

            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Custom Sleep Timer',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$selectedMinutes minutes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Will stop at $stopTimeStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 5,
                    max: 180,
                    divisions: 35,
                    activeColor: accent,
                    label: '$selectedMinutes min',
                    onChanged: (val) {
                      setDialogState(() {
                        selectedMinutes = val.toInt();
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: accent.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                    controller.setSleepTimer(
                      Duration(minutes: selectedMinutes),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Sleep timer set for $selectedMinutes min (stops at $stopTimeStr)',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  child: const Text('Start Timer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
