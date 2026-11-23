import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import 'core/audio/music_audio_handler.dart';
import 'core/audio/music_player_controller.dart';
import 'core/offline/download_notification_service.dart';
import 'core/offline/offline_download_service.dart';
import 'core/playlist/playlist_service.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/library/presentation/library_screen.dart';
import 'features/player/presentation/mini_player.dart';
import 'features/search/presentation/search_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

/// Global navigation key enabling background notification tap deep linking.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Entry point for Google Music Flutter application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DownloadNotificationService.initialize(rootNavigatorKey);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final audioHandler = await AudioService.init(
    builder: () => GoogleMusicAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mkx.google_music.playback',
      androidNotificationChannelName: 'Google Music Playback',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidNotificationClickStartsActivity: true,
      androidResumeOnClick: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: Color(0xFFFF4E4E),
    ),
  );

  final offlineService = OfflineDownloadService();
  await offlineService.initialize();

  final playlistService = PlaylistService();
  await playlistService.initialize();

  final playerController = MusicPlayerController(
    audioHandler: audioHandler,
    offlineService: offlineService,
    playlistService: playlistService,
  );
  await playerController.initialize();

  runApp(GoogleMusicApp(controller: playerController));
}

/// Root widget hosting theme and navigation scaffold.
class GoogleMusicApp extends StatelessWidget {
  /// The initialized music controller.
  final MusicPlayerController controller;

  /// Creates Google Music app instance.
  const GoogleMusicApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MusicPlayerController>.value(
      value: controller,
      child: Selector<MusicPlayerController, ({ThemeMode mode, Color accent})>(
        selector: (_, music) => (
          mode: music.themeMode,
          accent: music.dynamicAccentColor,
        ),
        builder: (context, themeProps, child) {
          final font = GoogleFonts.plusJakartaSans().fontFamily;

          /// Dynamically seed dark color scheme from active song's artwork accent color.
          final ColorScheme baseDarkScheme = ColorScheme.fromSeed(
            seedColor: themeProps.accent,
            brightness: Brightness.dark,
          );

          final Color dynamicDarkSurface = Color.alphaBlend(
            themeProps.accent.withValues(alpha: 0.04),
            const Color(0xFF0F0F13),
          );

          final Color dynamicDarkCard = baseDarkScheme.surfaceContainerHighest;

          final ColorScheme unifiedDarkScheme = baseDarkScheme.copyWith(
            primary: themeProps.accent,
            surface: dynamicDarkSurface,
            surfaceContainerHighest: dynamicDarkCard,
          );

          final ThemeData darkTheme = ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: dynamicDarkSurface,
            colorScheme: unifiedDarkScheme,
            fontFamily: font,
            snackBarTheme: SnackBarThemeData(
              backgroundColor: dynamicDarkCard,
              contentTextStyle: TextStyle(
                color: const Color(0xFFE6E1E5),
                fontFamily: font,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              behavior: SnackBarBehavior.floating,
              elevation: 4,
            ),
          );

          /// Google Light Mode Color Grading: Soft Google Snow surface subtly tinted by song palette.
          final ColorScheme baseLightScheme = ColorScheme.fromSeed(
            seedColor: themeProps.accent,
            brightness: Brightness.light,
          );

          final Color dynamicLightSurface = Color.alphaBlend(
            themeProps.accent.withValues(alpha: 0.04),
            const Color(0xFFF9F9FC),
          );

          final Color dynamicLightCard = Color.alphaBlend(
            themeProps.accent.withValues(alpha: 0.06),
            const Color(0xFFECEEF4),
          );

          final ColorScheme unifiedLightScheme = baseLightScheme.copyWith(
            primary: themeProps.accent,
            surface: dynamicLightSurface,
            surfaceContainerLowest: const Color(0xFFFFFFFF),
            surfaceContainerLow: const Color(0xFFF4F5F9),
            surfaceContainer: const Color(0xFFEBECEF),
            surfaceContainerHigh: const Color(0xFFE3E5EB),
            surfaceContainerHighest: dynamicLightCard,
            onSurface: const Color(0xFF191C1E),
            onSurfaceVariant: const Color(0xFF44474E),
          );

          final ThemeData lightTheme = ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: dynamicLightSurface,
            colorScheme: unifiedLightScheme,
            fontFamily: font,
            snackBarTheme: SnackBarThemeData(
              backgroundColor: dynamicLightCard,
              contentTextStyle: TextStyle(
                color: const Color(0xFF191C1E),
                fontFamily: font,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              behavior: SnackBarBehavior.floating,
              elevation: 4,
            ),
          );

          final isDark =
              themeProps.mode == ThemeMode.dark ||
              (themeProps.mode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);

          final M3EColorScheme m3eColorScheme =
              M3EColorScheme.fromSeed(
                themeProps.accent,
                brightness: isDark ? Brightness.dark : Brightness.light,
              ).copyWith(
                primary: themeProps.accent,
                surface: isDark ? dynamicDarkSurface : dynamicLightSurface,
                surfaceContainerHighest: isDark
                    ? dynamicDarkCard
                    : dynamicLightCard,
              );

          final m3eThemeData = M3EThemeData(colorScheme: m3eColorScheme)
              .copyWith(fontFamily: font);

          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'Google Music',
            debugShowCheckedModeBanner: false,
            themeMode: themeProps.mode,
            theme: lightTheme,
            darkTheme: darkTheme,
            builder: (context, appChild) {
              return M3ETheme(
                data: m3eThemeData,
                child: appChild ?? const SizedBox.shrink(),
              );
            },
            home: const GoogleMusicSplashScreen(
              nextScreen: MainNavigationShell(),
            ),
          );
        },
      ),
    );
  }
}

/// Root shell hosting the bottom navigation bar and mini player overlay.
class MainNavigationShell extends StatefulWidget {
  /// Creates navigation shell.
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedTab = 0;
  final ScrollController _homeScrollController = ScrollController();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      HomeScreen(
        scrollController: _homeScrollController,
        onSearchTapped: () => _onTabSelected(1),
      ),
      const SearchScreen(),
      LibraryScreen(onSearchTapped: () => _onTabSelected(1)),
      const SettingsScreen(),
    ];
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == 0 && _selectedTab == 0) {
      /// User tapped Home tab while already on Home: scroll smoothly to top.
      if (_homeScrollController.hasClients &&
          _homeScrollController.offset > 0) {
        _homeScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    setState(() {
      _selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final hasActiveSong = context.select<MusicPlayerController, bool>(
      (c) => c.currentSong != null,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: IndexedStack(index: _selectedTab, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasActiveSong) const MiniPlayerPill(),
          M3ENavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: _onTabSelected,
            size: M3ENavBarSize.small,
            destinations: const <M3ENavigationBarDestination>[
              M3ENavigationBarDestination(
                icon: Icon(M3EIcons.home_outlined),
                selectedIcon: Icon(M3EIcons.home_filled),
                label: 'Home',
              ),
              M3ENavigationBarDestination(
                icon: Icon(M3EIcons.search_outlined),
                selectedIcon: Icon(M3EIcons.search),
                label: 'Search',
              ),
              M3ENavigationBarDestination(
                icon: Icon(M3EIcons.library_music_outlined),
                selectedIcon: Icon(M3EIcons.library_music),
                label: 'Library',
              ),
              M3ENavigationBarDestination(
                icon: Icon(M3EIcons.settings_outlined),
                selectedIcon: Icon(M3EIcons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
