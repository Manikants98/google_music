import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/music_player_controller.dart';
import '../../../core/offline/download_notification_service.dart';
import '../../../core/update/app_update_service.dart';
import '../../player/presentation/sleep_timer_sheet.dart';
import '../../stats/presentation/stats_screen.dart';

/// Item descriptor for a settings action row.
class _SettingsItem {
  /// Leading icon.
  final IconData icon;

  /// Headline title.
  final String title;

  /// Descriptive subtitle.
  final String subtitle;

  /// Optional trailing widget.
  final Widget? trailing;

  /// Tap callback handler.
  final VoidCallback? onTap;

  /// Creates a settings item descriptor.
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
}

/// Settings and preferences screen designed with Google Music M3 Expressive card lists.
class SettingsScreen extends StatefulWidget {
  /// Creates settings screen.
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _developerTapCount = 0;
  DateTime? _lastTapTime;

  /// Displays an expressive floating SnackBar styled dynamically with active theme accent.
  void _showDynamicSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.read<MusicPlayerController>();
    final accent = controller.dynamicAccentColor;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.12 : 0.08),
          colorScheme.surfaceContainerHighest,
        ),
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: duration,
        content: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles 5-tap gesture on application version to unlock developer beta channel.
  void _handleVersionTap(
    BuildContext context,
    MusicPlayerController controller,
  ) {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _developerTapCount = 0;
    }
    _lastTapTime = now;
    _developerTapCount++;

    if (controller.isDeveloperModeEnabled) {
      _showDynamicSnackBar(
        context,
        message: 'Developer Options are active. Manage in section below.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    if (_developerTapCount >= 5) {
      _developerTapCount = 0;
      HapticFeedback.heavyImpact();
      controller.setDeveloperMode(true);
      controller.setBetaChannel(true);
      _showDynamicSnackBar(
        context,
        message: 'Developer Options unlocked. Beta Channel is active.',
        icon: Icons.developer_mode_rounded,
        duration: const Duration(seconds: 3),
      );
    } else if (_developerTapCount >= 2) {
      HapticFeedback.lightImpact();
      final remaining = 5 - _developerTapCount;
      _showDynamicSnackBar(
        context,
        message: '$remaining steps away from enabling Developer Options',
        icon: Icons.touch_app_rounded,
        duration: const Duration(milliseconds: 700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<MusicPlayerController>();
    final accent = controller.dynamicAccentColor;

    final String themeLabel = switch (controller.themeMode) {
      ThemeMode.system => 'System default',
      ThemeMode.dark => 'Dark theme',
      ThemeMode.light => 'Light theme',
    };
    final isDesktop = MediaQuery.sizeOf(context).width > 850;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        titleSpacing: isDesktop ? 24 : 12,
        title: Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          _buildSettingsGroup(
            context: context,
            title: 'Appearance',
            icon: Icons.palette_rounded,
            controller: controller,
            colorScheme: colorScheme,
            theme: theme,
            items: <_SettingsItem>[
              _SettingsItem(
                icon: Icons.brightness_6_rounded,
                title: 'Theme',
                subtitle: themeLabel,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        switch (controller.themeMode) {
                          ThemeMode.system => 'System',
                          ThemeMode.dark => 'Dark',
                          ThemeMode.light => 'Light',
                        },
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: accent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                onTap: () => _showThemeModal(context, controller),
              ),
              _SettingsItem(
                icon: Icons.auto_awesome_rounded,
                title: 'Dynamic Accent',
                subtitle: 'Theme colors adapt dynamically to song artwork',
                trailing: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              _SettingsItem(
                icon: Icons.waves_rounded,
                title: 'Fluid Animated Background',
                subtitle: 'Flowing organic liquid mesh canvas in Now Playing',
                trailing: Switch(
                  value: controller.isLiquidMeshEnabled,
                  activeThumbColor: accent,
                  onChanged: (bool value) =>
                      controller.setLiquidMeshEnabled(value),
                ),
              ),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: 'Insights & Analytics',
            icon: Icons.insights_rounded,
            controller: controller,
            colorScheme: colorScheme,
            theme: theme,
            items: <_SettingsItem>[
              _SettingsItem(
                icon: Icons.auto_graph_rounded,
                title: 'Listening Stats',
                subtitle:
                    'View your total listening time, top artists & music recap',
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const StatsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: 'Playback & Streaming',
            icon: Icons.play_circle_filled_rounded,
            controller: controller,
            colorScheme: colorScheme,
            theme: theme,
            items: <_SettingsItem>[
              _SettingsItem(
                icon: Icons.all_inclusive_rounded,
                title: 'Autoplay Continuous Music',
                subtitle: 'Queue similar tracks from YouTube Music when playback finishes',
                trailing: Switch(
                  value: controller.isAutoplayEnabled,
                  activeThumbColor: accent,
                  onChanged: (bool value) =>
                      controller.setAutoplayEnabled(value),
                ),
              ),
              _SettingsItem(
                icon: Icons.graphic_eq_rounded,
                title: 'Audio Quality',
                subtitle: 'High Fidelity (256 kbps AAC)',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HIGH',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              _SettingsItem(
                icon: Icons.psychology_rounded,
                title: 'Personalized Discovery',
                subtitle: 'Smart recommendations adapt to your listening taste',
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              _SettingsItem(
                icon: Icons.bedtime_outlined,
                title: 'Sleep Timer',
                subtitle: controller.isSleepTimerActive
                    ? (controller.isSleepTimerEndOfTrack
                          ? 'Active • Stops at end of track'
                          : 'Active • Scheduled shutdown')
                    : 'Turn off music automatically when you sleep',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (controller.isSleepTimerActive) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ON',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                onTap: () => SleepTimerSheet.show(context),
              ),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: 'Data & Storage',
            icon: Icons.storage_rounded,
            controller: controller,
            colorScheme: colorScheme,
            theme: theme,
            items: <_SettingsItem>[
              _SettingsItem(
                icon: Icons.history_rounded,
                title: 'Clear Listening History',
                subtitle:
                    '${controller.history.length} songs currently in history',
                trailing: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => _confirmClearHistory(context, controller),
              ),
              _SettingsItem(
                icon: Icons.cached_rounded,
                title: 'Clear Audio Cache',
                subtitle: 'Frees temporary stream memory and reloads tracks',
                trailing: Icon(
                  Icons.cleaning_services_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => _confirmClearCache(context, controller),
              ),
              _SettingsItem(
                icon: Icons.download_for_offline_rounded,
                title: 'Clear All Downloads',
                subtitle:
                    '${controller.downloadedSongs.length} songs saved (${controller.offlineService.formattedStorageUsed})',
                trailing: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => _confirmClearAllDownloads(context, controller),
              ),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: 'About',
            icon: Icons.info_outline_rounded,
            controller: controller,
            colorScheme: colorScheme,
            theme: theme,
            items: <_SettingsItem>[
              _SettingsItem(
                icon: Icons.music_note_rounded,
                title: 'Google Music',
                subtitle: 'Material 3 Expressive Audio Player',
                trailing: Text(
                  'v${AppUpdateService.currentAppVersion}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => _handleVersionTap(context, controller),
              ),
              _SettingsItem(
                icon: Icons.system_update_rounded,
                title: 'Check for Updates',
                subtitle: controller.isBetaChannelEnabled
                    ? 'Current: v${AppUpdateService.currentAppVersion} • Beta Channel'
                    : 'Current version: v${AppUpdateService.currentAppVersion}',
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => AppUpdateService.checkAndPrompt(
                  context,
                  manual: true,
                  includeBeta: controller.isBetaChannelEnabled,
                ),
              ),
              _SettingsItem(
                icon: Icons.code_rounded,
                title: 'Developer',
                subtitle: 'Mani Kant Sharma',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AUTHOR',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                onTap: () => DownloadNotificationService.openUrl(
                  'https://github.com/Manikants98',
                ),
              ),
              _SettingsItem(
                icon: Icons.stream_rounded,
                title: 'Music Engine',
                subtitle: 'Innertube API (WEB_REMIX)',
                trailing: Icon(Icons.verified_rounded, color: accent, size: 18),
              ),
            ],
          ),
          if (controller.isDeveloperModeEnabled)
            _buildSettingsGroup(
              context: context,
              title: 'Developer Options',
              icon: Icons.developer_mode_rounded,
              controller: controller,
              colorScheme: colorScheme,
              theme: theme,
              items: <_SettingsItem>[
                _SettingsItem(
                  icon: Icons.science_rounded,
                  title: 'Beta Channel Updates',
                  subtitle: controller.isBetaChannelEnabled
                      ? 'Enabled (Turn off to disable & hide this section)'
                      : 'Disabled',
                  trailing: Switch(
                    value: controller.isBetaChannelEnabled,
                    activeThumbColor: accent,
                    onChanged: (val) {
                      HapticFeedback.mediumImpact();
                      if (!val) {
                        controller.setBetaChannel(false);
                        controller.setDeveloperMode(false);
                        _showDynamicSnackBar(
                          context,
                          message: 'Developer Options disabled and hidden.',
                          icon: Icons.visibility_off_rounded,
                        );
                      } else {
                        controller.setBetaChannel(true);
                      }
                    },
                  ),
                ),
              ],
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Designed & Developed by ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Mani Kant Sharma',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Google Music • MKX Edition',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }

  /// Builds a grouped settings section using unified M3EList styling.
  Widget _buildSettingsGroup({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<_SettingsItem> items,
    required MusicPlayerController controller,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final isDesktop = MediaQuery.sizeOf(context).width > 850;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 12,
              8,
              isDesktop ? 24 : 12,
              10,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12),
            child: M3EList(
              color: colorScheme.surfaceContainerHighest,
              outerRadius: 12,
              innerRadius: 4,
              gap: 2,
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                return InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              item.icon,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.trailing != null) ...<Widget>[
                          const SizedBox(width: 8),
                          item.trailing!,
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Displays an expressive modal bottom sheet for theme mode selection.
  void _showThemeModal(BuildContext context, MusicPlayerController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = controller.dynamicAccentColor;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Choose Theme',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildThemeRow(
                  context: context,
                  title: 'System default',
                  subtitle: 'Matches device system appearance',
                  icon: Icons.brightness_auto_rounded,
                  selected: controller.themeMode == ThemeMode.system,
                  accent: accent,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () {
                    controller.setThemeMode(ThemeMode.system);
                    Navigator.of(context).pop();
                  },
                ),
                _buildThemeRow(
                  context: context,
                  title: 'Dark theme',
                  subtitle: 'Deep dark expressive contrast',
                  icon: Icons.dark_mode_rounded,
                  selected: controller.themeMode == ThemeMode.dark,
                  accent: accent,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () {
                    controller.setThemeMode(ThemeMode.dark);
                    Navigator.of(context).pop();
                  },
                ),
                _buildThemeRow(
                  context: context,
                  title: 'Light theme',
                  subtitle: 'Soft Google Snow palette',
                  icon: Icons.light_mode_rounded,
                  selected: controller.themeMode == ThemeMode.light,
                  accent: accent,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () {
                    controller.setThemeMode(ThemeMode.light);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds a clickable row for selecting a theme mode option.
  Widget _buildThemeRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color accent,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? accent : colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? accent : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }

  /// Shows confirmation alert dialog before wiping listening history.
  void _confirmClearHistory(
    BuildContext context,
    MusicPlayerController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = controller.dynamicAccentColor;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          icon: Icon(Icons.delete_sweep_rounded, color: accent, size: 28),
          title: Text(
            'Clear Listening History?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Text(
              'This will permanently remove all ${controller.history.length} recently played tracks from your library history.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
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
                controller.clearHistory();
                Navigator.of(context).pop();
                _showDynamicSnackBar(
                  context,
                  message: 'Listening history cleared',
                  icon: Icons.check_circle_rounded,
                );
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  /// Shows confirmation alert dialog before purging stream cache memory.
  void _confirmClearCache(
    BuildContext context,
    MusicPlayerController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = controller.dynamicAccentColor;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          icon: Icon(Icons.cleaning_services_rounded, color: accent, size: 28),
          title: Text(
            'Clear Audio Cache?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Text(
              'This will free up cached audio stream URLs and reload active streams from YouTube Music.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
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
                controller.clearStreamCache();
                Navigator.of(context).pop();
                _showDynamicSnackBar(
                  context,
                  message: 'Audio stream cache cleared',
                  icon: Icons.check_circle_rounded,
                );
              },
              child: const Text('Clear Cache'),
            ),
          ],
        );
      },
    );
  }

  /// Shows confirmation alert dialog before wiping offline downloads.
  void _confirmClearAllDownloads(
    BuildContext context,
    MusicPlayerController controller,
  ) {
    if (controller.downloadedSongs.isEmpty) {
      _showDynamicSnackBar(
        context,
        message: 'No downloaded songs found to delete',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final accent = controller.getLegibleAccentColor(
      Theme.of(context).brightness == Brightness.dark,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        icon: Icon(Icons.delete_sweep_rounded, color: accent, size: 28),
        title: Text(
          'Delete All Downloads?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Text(
            'This will permanently remove all ${controller.downloadedSongs.length} offline songs (${controller.offlineService.formattedStorageUsed}) from your device storage.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
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
            onPressed: () async {
              await controller.clearAllDownloads();
              if (context.mounted) {
                Navigator.of(context).pop();
                _showDynamicSnackBar(
                  context,
                  message: 'All offline downloads removed',
                  icon: Icons.check_circle_rounded,
                );
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}
