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
    final isDark = theme.brightness == Brightness.dark;

    final isActive = controller.isSleepTimerActive;
    final isEndOfTrack = controller.isSleepTimerEndOfTrack;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.22 : 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bedtime_rounded,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Sleep Timer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Audio will gently fade out and stop playback',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isActive) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.timer_rounded,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (isEndOfTrack)
                              Text(
                                'Stopping at end of track',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
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
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  }
                                  return Text(
                                    'Stopping in ${formatRemaining(remaining)}',
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 2),
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
                          backgroundColor:
                              colorScheme.errorContainer.withValues(alpha: 0.7),
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildPresetTile(
                context: context,
                controller: controller,
                title: '5 minutes',
                duration: const Duration(minutes: 5),
                accent: accent,
                colorScheme: colorScheme,
              ),
              _buildPresetTile(
                context: context,
                controller: controller,
                title: '15 minutes',
                duration: const Duration(minutes: 15),
                accent: accent,
                colorScheme: colorScheme,
              ),
              _buildPresetTile(
                context: context,
                controller: controller,
                title: '30 minutes',
                duration: const Duration(minutes: 30),
                accent: accent,
                colorScheme: colorScheme,
              ),
              _buildPresetTile(
                context: context,
                controller: controller,
                title: '45 minutes',
                duration: const Duration(minutes: 45),
                accent: accent,
                colorScheme: colorScheme,
              ),
              _buildPresetTile(
                context: context,
                controller: controller,
                title: '1 hour',
                duration: const Duration(hours: 1),
                accent: accent,
                colorScheme: colorScheme,
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isEndOfTrack
                        ? accent.withValues(alpha: 0.2)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.skip_next_rounded,
                    size: 20,
                    color: isEndOfTrack ? accent : colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  'End of track',
                  style: TextStyle(
                    fontWeight: isEndOfTrack ? FontWeight.w800 : FontWeight.w600,
                    color: isEndOfTrack ? accent : colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Playback stops when current track finishes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                trailing: isEndOfTrack
                    ? Icon(Icons.check_rounded, color: accent, size: 20)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.setSleepTimerEndOfTrack();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Sleep timer set to stop at end of track'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_calendar_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                title: const Text(
                  'Custom duration...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Choose custom minutes up to 4 hours',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => _showCustomDurationDialog(context, controller, accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a selectable preset duration tile with projected stop time.
  Widget _buildPresetTile({
    required BuildContext context,
    required MusicPlayerController controller,
    required String title,
    required Duration duration,
    required Color accent,
    required ColorScheme colorScheme,
  }) {
    final targetTime = DateTime.now().add(duration);
    final stopTimeStr = formatStopTime(targetTime);

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.access_time_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Stops around $stopTimeStr',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
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
            final targetTime =
                DateTime.now().add(Duration(minutes: selectedMinutes));
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
                    controller.setSleepTimer(Duration(minutes: selectedMinutes));
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
