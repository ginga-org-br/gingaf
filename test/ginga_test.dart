import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gingaf/ginga.dart';
import 'package:nclui/ncl.dart';
import 'package:plugins/plugins_registry.dart';
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
      registerAllPlugins(GetIt.instance);
    });

    testWidgets('NclWidget mounts video360 example',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: NclWidget(src: 'examples/video360/main.ncl360'),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
    });

    testWidgets('NclWidget mounts example', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(src: '../examples/video.ncl'),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
    });

    testWidgets('AVWidget resizes when window is resized',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: NclWidget(src: 'examples/video.ncl'),
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AVWidget), findsOneWidget);
      final initialRect = tester.getRect(find.byType(AVWidget));

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pump();
      final resizedRect = tester.getRect(find.byType(AVWidget));

      expect(initialRect.size, equals(const Size(800, 600)));
      expect(resizedRect.size, equals(const Size(1200, 900)));
    });

    testWidgets('Ginga player resizes AVWidget when window is resized',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gingacc = GingaCC(
        config: GingaConfig(appSrc: 'examples/video.ncl', enablePlayground: false),
      );
      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AVWidget), findsOneWidget);
      final initialRect = tester.getRect(find.byType(AVWidget));

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pump();
      final resizedRect = tester.getRect(find.byType(AVWidget));

      expect(initialRect.size, equals(const Size(800, 600)));
      expect(resizedRect.size, equals(const Size(1200, 900)));
    });

    testWidgets('Ginga playground resizes AVWidget to player area',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gingacc = GingaCC(
        config: GingaConfig(appSrc: 'examples/video.ncl', enablePlayground: true),
      )..setVirtualFiles({
        'examples/video.ncl': '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="video.mp4"/>
  </body>
</ncl>''',
      });
      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(seconds: 1));

      final runBtn = find.byKey(const Key('monaco_run_button'));
      expect(runBtn, findsOneWidget);
      await tester.tap(runBtn);
      await tester.pumpAndSettle();

      final avFinder = find.byType(AVWidget);
      expect(avFinder, findsOneWidget);
      final playerRect = tester.getRect(avFinder);
      expect(playerRect.width, equals(500.0));

      tester.view.physicalSize = const Size(1400, 800);
      await tester.pump();
      final resizedRect = tester.getRect(avFinder);
      expect(resizedRect.width, equals(700.0));
      expect(resizedRect.height, equals(800.0));
      expect(resizedRect.left, equals(700.0));
    });

    testWidgets('NclWidget pauses and resumes AVWidget media',
        (WidgetTester tester) async {
      final gingacc = GingaCC()..setVirtualFiles(testVirtualFiles);
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
      )..setVirtualFiles(testVirtualFiles);
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
      )..setVirtualFiles(testVirtualFiles);
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
      expect(htmlWidget.gingacc.config.startWithCCWS, isTrue);
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
      )..setVirtualFiles(testVirtualFiles);
      await tester.pumpWidget(Ginga(gingacc: gingacc));

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
      )..setVirtualFiles(testVirtualFiles);
      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('floating_control_menu')), findsOneWidget);
      expect(
          find.byKey(const Key('floating_menu_toggle_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('floating_restart_button')), findsOneWidget);
      expect(find.byKey(const Key('floating_pause_button')), findsOneWidget);
      expect(
          find.byKey(const Key('floating_forward_2s_button')), findsOneWidget);
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

      await tester
          .tap(find.byKey(const Key('user_selection_manage_users_button')));
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

    testWidgets(
        'FloatingControlMenu Forward 2s pauses presentation, ticks 2s per click, and resumes on play',
        (WidgetTester tester) async {
      final config = GingaConfig(
        appSrc: 'test_forward.ncl',
        startWithMainAv: false,
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles(
          {
            'test_forward.ncl': '''
<ncl id="test_forward" >
  <head>
    <regionBase>
      <region id="rg1" width="100%" height="100%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="d1" region="rg1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="m1.mp4" descriptor="d1"/>
  </body>
</ncl>
''',
          },
        );
      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 500));

      final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclState.isPaused, isFalse);

      await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final forwardButtonFinder =
          find.byKey(const Key('floating_forward_2s_button'));
      final pauseButtonFinder = find.byKey(const Key('floating_pause_button'));

      expect(forwardButtonFinder, findsOneWidget);
      expect(pauseButtonFinder, findsOneWidget);

      final forwardOffset = tester.getTopLeft(forwardButtonFinder);
      final pauseOffset = tester.getTopLeft(pauseButtonFinder);
      expect(forwardOffset.dy, lessThan(pauseOffset.dy));
      expect(forwardOffset.dx, equals(pauseOffset.dx));

      final initialClock = nclState.nclDocument!.scheduler.virtualClock;

      await tester.tap(forwardButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(nclState.isPaused, isTrue);
      expect(nclState.nclDocument!.scheduler.virtualClock,
          equals(initialClock + 2000));
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(forwardButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(nclState.isPaused, isTrue);
      expect(nclState.nclDocument!.scheduler.virtualClock,
          equals(initialClock + 4000));
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(pauseButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(nclState.isPaused, isFalse);
      expect(find.text('Pause'), findsOneWidget);
    });

    test('GingaConfig parses enablePlayground from JSON and constructor', () async {
      final configDefault = GingaConfig();
      expect(configDefault.enablePlayground, isFalse);

      final configExplicit = GingaConfig(enablePlayground: true);
      expect(configExplicit.enablePlayground, isTrue);
      expect(configExplicit.toString(), contains('enablePlayground: true'));

      final configJsonCamel = await GingaConfig.fromJson(
        '{"enablePlayground": true, "appSrc": "main.ncl"}',
      );
      expect(configJsonCamel.enablePlayground, isTrue);
    });

    testWidgets(
        'Ginga widget includes PlaygroundEditor widget open with current main app file content when enablePlayground is true',
        (WidgetTester tester) async {
      const sampleNcl = '<ncl id="playgroundApp"><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>';
      final config = await GingaConfig.fromJson(
        '{"enablePlayground": true, "appSrc": "playground.ncl"}',
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'playground.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 500));

      final monacoFinder = find.byType(PlaygroundEditor);
      expect(monacoFinder, findsOneWidget);

      final monacoKeyFinder = find.byKey(const Key('flutter_monaco_widget'));
      expect(monacoKeyFinder, findsOneWidget);

      expect(find.text('playground.ncl'), findsOneWidget);
      expect(find.text('Monaco Editor'), findsOneWidget);

      final monacoState = tester.state<PlaygroundEditorState>(monacoFinder);
      expect(monacoState.effectiveContent, equals(sampleNcl));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga widget does not include PlaygroundEditor when enablePlayground is false',
        (WidgetTester tester) async {
      final config = GingaConfig(
        appSrc: 'normal.ncl',
        enablePlayground: false,
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'normal.ncl': '<ncl id="normal"/>',
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PlaygroundEditor), findsNothing);
      expect(find.byKey(const Key('flutter_monaco_widget')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga widget mounts PlaygroundEditor when enablePlayground is enabled via copyWith',
        (WidgetTester tester) async {
      var config = GingaConfig(
        appSrc: 'normal.ncl',
        enablePlayground: false,
      );
      config = config.copyWith(enablePlayground: true);
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'normal.ncl': '<ncl id="normal"/>',
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PlaygroundEditor), findsOneWidget);
      expect(find.byKey(const Key('flutter_monaco_widget')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga mounts PlaygroundEditor on the left side of the player',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sampleNcl =
          '<ncl id="pg"><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>';
      final config = GingaConfig(
        enablePlayground: true,
        appSrc: 'playground.ncl',
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'playground.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final editorFinder = find.byType(PlaygroundEditor);
      expect(editorFinder, findsOneWidget);

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump(const Duration(milliseconds: 300));

      final nclFinder = find.byType(NclWidget);
      expect(nclFinder, findsOneWidget);

      final editorRect = tester.getRect(editorFinder);
      final nclRect = tester.getRect(nclFinder);
      expect(editorRect.left, equals(0.0));
      expect(editorRect.right, lessThanOrEqualTo(nclRect.left));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga keeps playground alive and does not exit when NclWidgetExitNotification is received in playground mode',
        (WidgetTester tester) async {
      const sampleNcl =
          '<ncl id="pg"><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>';
      final config = GingaConfig(
        enablePlayground: true,
        appSrc: 'playground.ncl',
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'playground.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump(const Duration(milliseconds: 300));

      final gingaState = tester.state<GingaState>(find.byType(Ginga));
      expect(gingaState.isExiting, isFalse);

      NclWidgetExitNotification()
          .dispatch(tester.element(find.byType(NclWidget)));
      await tester.pump(const Duration(milliseconds: 300));

      expect(gingaState.isExiting, isFalse);
      expect(find.byType(PlaygroundEditor), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga cleans up and exits when NclWidgetExitNotification is received outside playground mode',
        (WidgetTester tester) async {
      const sampleNcl =
          '<ncl id="normal"><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>';
      final config = GingaConfig(
        enablePlayground: false,
        appSrc: 'normal.ncl',
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'normal.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final gingaState = tester.state<GingaState>(find.byType(Ginga));
      expect(gingaState.isExiting, isFalse);

      NclWidgetExitNotification()
          .dispatch(tester.element(find.byType(NclWidget)));
      await tester.pump(const Duration(milliseconds: 300));

      expect(gingaState.isExiting, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga playground handles debug start, stop, and virtualFiles without unmodifiable map errors',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const sampleNcl = '''<ncl id="dbg">
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="m1.mp4"/>
  </body>
</ncl>''';
      final config = GingaConfig(
        enablePlayground: true,
        appSrc: 'dbg.ncl',
        breakpoints: [4],
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'dbg.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump();

      final gingaState = tester.state<GingaState>(find.byType(Ginga));
      expect(gingaState.isRunning, isFalse);

      final pEditor =
          tester.widget<PlaygroundEditor>(find.byType(PlaygroundEditor));
      expect(pEditor.isRunning, isFalse);

      expect(find.byKey(const Key('monaco_stop_button')), findsNothing);
      expect(find.byKey(const Key('monaco_debug_continue_button')), findsNothing);

      final debugFinder = find.byKey(const Key('monaco_debug_start_button'));
      expect(debugFinder, findsOneWidget);
      await tester.tap(debugFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(gingaState.isRunning, isTrue);

      final stopFinder = find.byKey(const Key('monaco_stop_button'));
      expect(stopFinder, findsOneWidget);

      final continueFinder =
          find.byKey(const Key('monaco_debug_continue_button'));
      expect(continueFinder, findsOneWidget);
      await tester.tap(continueFinder);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(stopFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(gingaState.isRunning, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga playground does not display continue or stop buttons when running without debugging',
        (WidgetTester tester) async {
      const sampleNcl =
          '<ncl id="pg"><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>';
      final config = GingaConfig(
        enablePlayground: true,
        appSrc: 'playground.ncl',
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'playground.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('monaco_stop_button')), findsNothing);
      expect(find.byKey(const Key('monaco_debug_continue_button')), findsNothing);
      expect(find.byKey(const Key('monaco_debug_start_button')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga playground displays "No running application" placeholder when idle and hides it when running',
        (WidgetTester tester) async {
      const sampleNcl =
          '<ncl id="pg"><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>';
      final config = GingaConfig(
        enablePlayground: true,
        appSrc: 'playground.ncl',
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'playground.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('no_running_app_placeholder')), findsOneWidget);
      expect(find.text('No running application'), findsOneWidget);

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('no_running_app_placeholder')), findsNothing);
      expect(find.byType(NclWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('monaco_stop_button')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('no_running_app_placeholder')), findsOneWidget);
      expect(find.text('No running application'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Ginga playground continues from one breakpoint to another',
        (WidgetTester tester) async {
      const sampleNcl = '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="video.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="green_bg">
      <property name="background" value="green"/>
    </media>
    <media id="red_bg">
      <property name="background" value="red"/>
      <property name="explicitDur" value="2s"/>
    </media>
    <link id="l1">
      <bind role="onBegin" component="video" interface="a1"/>
      <bind role="start" component="green_bg"/>
    </link>
    <link id="l2">
      <bind role="onEnd" component="video" interface="a1"/>
      <bind role="stop" component="green_bg"/>
      <bind role="start" component="red_bg"/>
    </link>
  </body>
</ncl>''';
      final config = GingaConfig(
        enablePlayground: true,
        appSrc: 'video.ncl',
        breakpoints: [7, 11],
      );
      final gingacc = GingaCC(
        config: config,
      )..setVirtualFiles({
          'video.ncl': sampleNcl,
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pumpAndSettle();

      final runBtn = find.byKey(const Key('monaco_run_button'));
      expect(runBtn, findsOneWidget);
      await tester.tap(runBtn);
      await tester.pump(const Duration(milliseconds: 300));

      final nclFinder = find.byType(NclWidget);
      expect(nclFinder, findsOneWidget);
      final nclState = tester.state<NclWidgetState>(nclFinder);

      final pState = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));

      nclState.tick(2500);
      await tester.pump();

      expect(pState.isPaused, isTrue);
      expect(pState.currentDebugLine, equals(7));

      final continueBtn = find.byKey(const Key('monaco_debug_continue_button'));
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pump();
      expect(pState.isPaused, isFalse);

      nclState.tick(2000);
      await tester.pump();

      expect(pState.isPaused, isTrue);
      expect(pState.currentDebugLine, equals(11));

      await tester.tap(continueBtn);
      await tester.pump();
      expect(pState.isPaused, isFalse);
      expect(nclState.isPaused, isFalse);

      nclState.tick(2500);
      await tester.pump();
      expect(pState.isPaused, isFalse);
      expect(nclState.isPaused, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Ginga keeps running and does not exit when ESC is pressed in playground mode',
        (WidgetTester tester) async {
      final gingacc = GingaCC(
        config: GingaConfig(appSrc: 'examples/video.ncl', enablePlayground: true),
      )..setVirtualFiles({
          'examples/video.ncl': '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="video.mp4"/>
  </body>
</ncl>''',
        });

      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(PlaygroundEditor), findsOneWidget);
      expect(find.byType(Ginga), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}

