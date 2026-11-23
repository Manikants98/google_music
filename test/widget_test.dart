import 'package:flutter_test/flutter_test.dart';
import 'package:google_music/core/audio/music_player_controller.dart';
import 'package:google_music/main.dart';

/// Smoke test verifying GoogleMusicApp instantiation.
void main() {
  testWidgets('GoogleMusicApp smoke test', (WidgetTester tester) async {
    final controller = MusicPlayerController();
    await tester.pumpWidget(GoogleMusicApp(controller: controller));
    expect(find.text('Google Music'), findsOneWidget);
  });
}
