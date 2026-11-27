import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_route_service.dart';
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

/// Custom scroll behavior that completely removes scrollbar thumbs while enabling smooth dragging across all devices.
class HiddenScrollBehavior extends MaterialScrollBehavior {
  /// Creates hidden scrollbar behavior.
  const HiddenScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// Global navigation key enabling background notification tap deep linking.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Entry point for Google Music Flutter application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  await AudioRouteService.instance.initialize();

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
        selector: (_, music) =>
            (mode: music.themeMode, accent: music.dynamicAccentColor),
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
                borderRadius: BorderRadius.circular(16),
              ),
              behavior: SnackBarBehavior.floating,
              elevation: 8,
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
                borderRadius: BorderRadius.circular(16),
              ),
              behavior: SnackBarBehavior.floating,
              elevation: 8,
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
            scrollBehavior: const HiddenScrollBehavior(),
            themeMode: themeProps.mode,
            theme: lightTheme,
            darkTheme: darkTheme,
            builder: (context, appChild) {
              return ScrollConfiguration(
                behavior: const HiddenScrollBehavior(),
                child: M3ETheme(
                  data: m3eThemeData,
                  child: appChild ?? const SizedBox.shrink(),
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final accent = context.select<MusicPlayerController, Color>(
      (c) => c.dynamicAccentColor,
    );
    final hasActiveSong = context.select<MusicPlayerController, bool>(
      (c) => c.currentSong != null,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth > 750;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true,
      body: IndexedStack(index: _selectedTab, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasActiveSong)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 5,
                0,
                isDesktop ? 24 : 5,
                2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: const MiniPlayerPill(),
                ),
              ),
            ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer.withValues(
                    alpha: isDark ? 0.85 : 0.90,
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 36 : 16,
                      vertical: 8,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: GNav(
                          selectedIndex: _selectedTab,
                          onTabChange: _onTabSelected,
                          gap: 8,
                          activeColor: accent,
                          iconSize: 22,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          duration: const Duration(milliseconds: 350),
                          tabBackgroundColor: accent.withValues(alpha: 0.16),
                          color: colorScheme.onSurfaceVariant,
                          tabBorderRadius: 24,
                          textStyle: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          tabs: const <GButton>[
                            GButton(icon: Icons.home_rounded, text: 'Home'),
                            GButton(icon: Icons.search_rounded, text: 'Search'),
                            GButton(
                              icon: Icons.library_music_rounded,
                              text: 'Library',
                            ),
                            GButton(
                              icon: Icons.settings_rounded,
                              text: 'Settings',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
