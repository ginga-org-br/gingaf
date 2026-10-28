import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/menu/settings_menu.dart';

Widget _buildTestWrapper({
  VoidCallback? onReload,
  VoidCallback? onRestart,
  VoidCallback? onTogglePause,
  VoidCallback? onOpenUsers,
  bool isPaused = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          SettingsMenu(
            onReload: onReload,
            onRestart: onRestart,
            onTogglePause: onTogglePause ?? () {},
            onOpenUsers: onOpenUsers ?? () {},
            isPaused: isPaused,
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('SettingsMenu Widget Tests', () {
    testWidgets('renders collapsed state initially', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          onRestart: () {},
        ),
      );

      expect(
          find.byKey(const Key('floating_menu_toggle_button')), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byKey(const Key('floating_users_button')), findsNothing);
      expect(find.byKey(const Key('floating_pause_button')), findsNothing);
      expect(find.byKey(const Key('floating_restart_button')), findsNothing);
      expect(find.text('Users'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Restart'), findsNothing);
    });

    testWidgets('tapping toggle button expands and collapses menu',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          onRestart: () {},
        ),
      );

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byKey(const Key('floating_users_button')), findsOneWidget);
      expect(find.byKey(const Key('floating_pause_button')), findsOneWidget);
      expect(find.byKey(const Key('floating_restart_button')), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byKey(const Key('floating_users_button')), findsNothing);
      expect(find.byKey(const Key('floating_pause_button')), findsNothing);
      expect(find.byKey(const Key('floating_restart_button')), findsNothing);
    });

    testWidgets(
        'tapping pause button triggers callback and updates icon and label',
        (tester) async {
      int pauseCallCount = 0;
      bool isPaused = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _buildTestWrapper(
              onRestart: () {},
              onTogglePause: () {
                pauseCallCount++;
                setState(() {
                  isPaused = !isPaused;
                });
              },
              isPaused: isPaused,
            );
          },
        ),
      );

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pause'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      await tester.tap(find.byKey(const Key('floating_pause_button')));
      await tester.pumpAndSettle();

      expect(pauseCallCount, equals(1));
      expect(find.text('Resume'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);

      await tester.tap(find.byKey(const Key('floating_pause_button')));
      await tester.pumpAndSettle();

      expect(pauseCallCount, equals(2));
      expect(find.text('Pause'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('tapping restart button triggers onRestart and collapses menu',
        (tester) async {
      int restartCallCount = 0;

      await tester.pumpWidget(
        _buildTestWrapper(
          onRestart: () {
            restartCallCount++;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('floating_restart_button')));
      await tester.pumpAndSettle();

      expect(restartCallCount, equals(1));
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byKey(const Key('floating_restart_button')), findsNothing);
    });

    testWidgets(
        'tapping restart button triggers onReload when onRestart is null',
        (tester) async {
      int reloadCallCount = 0;

      await tester.pumpWidget(
        _buildTestWrapper(
          onReload: () {
            reloadCallCount++;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('floating_restart_button')));
      await tester.pumpAndSettle();

      expect(reloadCallCount, equals(1));
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byKey(const Key('floating_restart_button')), findsNothing);
    });

    testWidgets('tapping users button triggers onOpenUsers and collapses menu',
        (tester) async {
      int usersCallCount = 0;

      await tester.pumpWidget(
        _buildTestWrapper(
          onRestart: () {},
          onOpenUsers: () {
            usersCallCount++;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('floating_users_button')));
      await tester.pumpAndSettle();

      expect(usersCallCount, equals(1));
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byKey(const Key('floating_users_button')), findsNothing);
    });
  });
}
