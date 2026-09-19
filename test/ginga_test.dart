import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:nclui/ncl.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

const testVirtualFiles = {
  'test.ncl':
      '<ncl><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>',
  'test/user_data1.json': '[{"id": "u400", "name": "ConfUser"}]',
  'test/user_data2.json': '[{"id": "uConfig", "name": "GingaConfigUser"}]',
};

void main() {
  group('Widget Tests', () {
    setUp(() {
      VideoPlayerPlatform.instance = MockVideoPlayer();
    });

    testWidgets('NclWidget mounts example', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(src: '../examples/video.ncl'),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
    });

    testWidgets('NclWidget pauses and resumes AVWidget media',
        (WidgetTester tester) async {
      final gingacc = GingaCC(
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(
          src: 'test.ncl',
          gingacc: gingacc,
        ),
      ));

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AVWidget), findsOneWidget);

      final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
      final avState = tester.state<AVWidgetState>(find.byType(AVWidget));
      expect(avState.isPaused, isFalse);

      nclState.pause();
      await tester.pump();
      expect(avState.isPaused, isTrue);

      nclState.resume();
      await tester.pump();
      expect(avState.isPaused, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('NclWidget mounts with config parameter',
        (WidgetTester tester) async {
      final config = GingaConfig(
        users: Users('{"id": "u400", "name": "ConfUser"}'),
      );
      final gingacc = GingaCC(
        config: config,
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(
          src: 'test.ncl',
          gingacc: gingacc,
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
      final nclWidgetState =
          tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclWidgetState.nclDocument, isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('u400'), isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('u400')?.name,
          equals('ConfUser'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('NclWidget mounts with GingaConfig from JSON',
        (WidgetTester tester) async {
      final config = await GingaConfig.fromJson(
        '{"usersDataJson": [{"id": "uConfig", "name": "GingaConfigUser"}]}',
      );
      final gingacc = GingaCC(
        config: config,
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(
          src: 'test.ncl',
          gingacc: gingacc,
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
      final nclWidgetState =
          tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclWidgetState.nclDocument, isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('uConfig'), isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('uConfig')?.name,
          equals('GingaConfigUser'));
      await tester.pumpWidget(const SizedBox());
    });

    test('HtmlWidget accepts gingacc parameter', () {
      final gingacc = GingaCC(config: GingaConfig(startWithCCWS: true));
      final htmlWidget = HtmlWidget(
        src: 'app.html',
        gingacc: gingacc,
      );
      expect(htmlWidget.gingacc?.config.startWithCCWS, isTrue);
      expect(htmlWidget.src, equals('app.html'));
    });

    testWidgets(
        'Ginga mounts single MainAVWidget and plays when app is running',
        (WidgetTester tester) async {
      final config = GingaConfig(
        appSrc: 'test.ncl',
        mainAvSrc: 'examples/primeiro-joao/media/animGar.mp4',
        startWithMainAv: true,
        startWithCCWS: false,
      );
      final gingacc = GingaCC(
        config: config,
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MainAVWidget), findsOneWidget);
      expect(find.byType(NclWidget), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'FloatingControlMenu toggles, pauses, reloads, and opens Netflix users overlay',
        (WidgetTester tester) async {
      final config = GingaConfig(
        appSrc: 'test.ncl',
        startWithCCWS: false,
        users: Users(
            '[{"id": "u1", "name": "Alice"}, {"id": "u2", "name": "Bob"}]'),
      );
      final gingacc = GingaCC(
        config: config,
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('floating_control_menu')), findsOneWidget);
      expect(
          find.byKey(const Key('floating_menu_toggle_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('floating_restart_button')), findsOneWidget);
      expect(find.byKey(const Key('floating_pause_button')), findsOneWidget);
      expect(find.byKey(const Key('floating_users_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating_pause_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclState.isPaused, isTrue);

      await tester.tap(find.byKey(const Key('floating_pause_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(nclState.isPaused, isFalse);

      await tester.tap(find.byKey(const Key('floating_restart_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(NclWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('floating_users_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('user_selection_overlay')), findsOneWidget);
      expect(find.text('Who is the current user?'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byKey(const Key('delete_badge_u1')), findsNothing);

      expect(gingacc.config.users.allUsers.length, equals(2));
      await tester
          .tap(find.byKey(const Key('user_selection_manage_users_button')));
      await tester.pump();
      expect(find.byKey(const Key('remove_user_u1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove_user_u1')));
      await tester.pump(const Duration(milliseconds: 250));

      expect(gingacc.config.users.allUsers.length, equals(1));
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byKey(const Key('add_user_card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_user_card')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add User'), findsWidgets);
      await tester.enterText(
          find.byKey(const Key('add_user_name_input')), 'Charlie');
      await tester.enterText(find.byKey(const Key('add_user_age_input')), '25');
      await tester.enterText(
          find.byKey(const Key('add_user_gender_input')), 'female');

      await tester.tap(find.byKey(const Key('add_user_save_button')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(gingacc.config.users.allUsers.length, equals(2));
      expect(find.text('Charlie'), findsOneWidget);
      final charlie =
          gingacc.config.users.allUsers.firstWhere((u) => u.name == 'Charlie');
      expect(charlie.getProperty('age'), equals(25));
      expect(charlie.getProperty('gender'), equals('female'));

      await tester
          .tap(find.byKey(const Key('user_selection_manage_users_button')));
      await tester.pump();
      expect(find.byKey(const Key('add_user_card')), findsNothing);

      await tester.tap(find.byKey(const Key('user_selection_close_button')));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('user_selection_overlay')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'UserSelectionOverlay manages users, selects current user, and shows empty state',
        (WidgetTester tester) async {
      final users =
          Users('[{"id": "u1", "name": "Dad"}, {"id": "u2", "name": "Quinn"}]');
      bool closed = false;
      UserData? selected;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UsersMenu(
            users: users,
            onClose: () => closed = true,
            onUserSelected: (u) => selected = u,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Who is the current user?'), findsOneWidget);
      expect(find.text('Dad'), findsOneWidget);
      expect(find.text('Quinn'), findsOneWidget);

      await tester
          .tap(find.byKey(const Key('user_selection_manage_users_button')));
      await tester.pump();
      expect(find.text('Done'), findsOneWidget);
      expect(find.byKey(const Key('remove_user_u1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove_user_u1')));
      await tester.pump();
      expect(users.getUser('u1'), isNull);
      expect(find.text('Dad'), findsNothing);
      expect(find.text('Quinn'), findsOneWidget);

      await tester
          .tap(find.byKey(const Key('user_selection_manage_users_button')));
      await tester.pump();
      expect(find.text('Manage Users'), findsOneWidget);

      await tester.tap(find.text('Quinn'));
      await tester.pump();
      expect(selected?.id, equals('u2'));
      expect(closed, isFalse);

      await tester.tap(find.byKey(const Key('user_selection_close_button')));
      await tester.pump();
      expect(closed, isTrue);

      users.clear();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UsersMenu(
            users: users,
            onClose: () {},
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('No users found'), findsOneWidget);
    });

    testWidgets('UsersMenu invokes dispatchCurrentUserUpdate on user selection',
        (tester) async {
      final users = Users(
          '[{"id": "u1", "name": "Bob", "gender": "male", "age": 25}, {"id": "u2", "name": "Alice", "gender": "female", "age": 30}]');
      final systemVars = <String, String>{};

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UsersMenu(
            users: users,
            onClose: () {},
            dispatchCurrentUserUpdate: (name, value) {
              systemVars[name] = value;
            },
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Alice'));
      await tester.pump();

      expect(users.currentUser?.id, equals('u2'));
      expect(systemVars['id'], equals('u2'));
      expect(systemVars['name'], equals('Alice'));
      expect(systemVars['gender'], equals('female'));
      expect(systemVars['age'], equals('30'));
    });

    testWidgets(
        'UsersMenu renders multiple users in the same row without wrapping',
        (tester) async {
      final users = Users(
          '[{"id": "u1", "name": "User 1"}, {"id": "u2", "name": "User 2"}, {"id": "u3", "name": "User 3"}, {"id": "u4", "name": "User 4"}]');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UsersMenu(
            users: users,
            onClose: () {},
          ),
        ),
      ));
      await tester.pump();

      final y1 = tester.getTopLeft(find.byKey(const Key('user_card_u1'))).dy;
      final y2 = tester.getTopLeft(find.byKey(const Key('user_card_u2'))).dy;
      final y3 = tester.getTopLeft(find.byKey(const Key('user_card_u3'))).dy;
      final y4 = tester.getTopLeft(find.byKey(const Key('user_card_u4'))).dy;

      expect(y1, equals(y2));
      expect(y2, equals(y3));
      expect(y3, equals(y4));
    });

    testWidgets('UsersMenu Add User age field only accepts digits',
        (tester) async {
      final users = Users();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UsersMenu(
            users: users,
            onClose: () {},
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(
          find.byKey(const Key('user_selection_manage_users_button')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('add_user_card')));
      await tester.pumpAndSettle();

      final ageFinder = find.byKey(const Key('add_user_age_input'));
      expect(ageFinder, findsOneWidget);

      await tester.enterText(ageFinder, 'abc25xyz');
      await tester.pump();

      final TextField ageField = tester.widget(ageFinder);
      expect(ageField.controller?.text, equals('25'));
    });
  });
}
