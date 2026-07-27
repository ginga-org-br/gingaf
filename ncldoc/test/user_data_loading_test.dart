import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCL Users API Core Tests', () {
    test('NCLUserData stores and updates properties correctly', () {
      final user = NCLUserData(
        id: 'user1',
        name: 'Alice',
        initialProperties: {'age': 25, 'language': 'pt-BR'},
      );

      expect(user.id, equals('user1'));
      expect(user.name, equals('Alice'));
      expect(user.getProperty('age'), equals(25));
      expect(user.getProperty('language'), equals('pt-BR'));
      expect(user.hasProperty('age'), isTrue);
      expect(user.hasProperty('gender'), isFalse);

      user.setProperty('theme', 'dark');
      expect(user.getProperty('theme'), equals('dark'));
    });

    test('Users registers and sets active users', () {
      final manager = NCLUsers();

      final user1 = NCLUserData(id: 'u1', name: 'User One');
      final user2 = NCLUserData(id: 'u2', name: 'User Two');

      manager.registerUser(user1);
      manager.registerUser(user2);

      expect(manager.allUsers.length, equals(2));
      expect(manager.activeUser?.id, equals('u1'));

      manager.setActiveUser('u2');
      expect(manager.activeUser?.id, equals('u2'));
      expect(manager.getUser('u1')?.name, equals('User One'));
    });

    test('Users gets and sets user properties synchronously', () {
      final manager = NCLUsers();
      final user = NCLUserData(id: 'u1', name: 'User One');
      manager.registerUser(user);

      expect(manager.setUserProperty('u1', 'preferredQuality', 'HD'), isTrue);
      expect(manager.getUserProperty('u1', 'preferredQuality'), equals('HD'));

      manager.removeUser('u1');
      expect(manager.getUser('u1'), isNull);
      expect(manager.activeUser, isNull);
    });
  });

  group('NCL User Serialization Tests', () {
    test('NCLUserData serializes to JSON and deserializes from JSON', () {
      final user = NCLUserData(
        id: 'user1',
        name: 'Alice',
        initialProperties: {'age': 25, 'lang': 'pt-BR'},
      );

      final json = user.toJson();
      expect(json['id'], equals('user1'));
      expect(json['name'], equals('Alice'));
      expect(json['age'], equals(25));
      expect(json['lang'], equals('pt-BR'));

      final restoredUser = NCLUserData.fromJson(json);
      expect(restoredUser.id, equals('user1'));
      expect(restoredUser.name, equals('Alice'));
      expect(restoredUser.getProperty('age'), equals(25));
      expect(restoredUser.getProperty('lang'), equals('pt-BR'));
    });

    test('Users exports and imports users JSON list', () {
      final manager = NCLUsers();
      manager.registerUser(
        NCLUserData(id: 'u1', name: 'Bob', initialProperties: {'device': 'tv'}),
      );
      manager.registerUser(
        NCLUserData(
          id: 'u2',
          name: 'Carol',
          initialProperties: {'device': 'mobile'},
        ),
      );

      final exported = manager.allUsers.map((u) => u.toJson()).toList();
      expect(exported.length, equals(2));

      final newManager = NCLUsers();
      newManager.importUsers(exported);

      expect(newManager.allUsers.length, equals(2));
      expect(newManager.getUserProperty('u1', 'device'), equals('tv'));
      expect(newManager.getUserProperty('u2', 'device'), equals('mobile'));
    });
  });

  group('NCL Users Session Management Tests', () {
    late NCLUsers manager;

    setUp(() {
      manager = NCLUsers();
      manager.registerUser(NCLUserData(id: 'u1', name: 'Alice'));
      manager.registerUser(NCLUserData(id: 'u2', name: 'Bob'));
    });

    test('createUsersSession and getUsersSessionIds', () {
      expect(manager.createUsersSession('session1'), isTrue);
      expect(manager.createUsersSession('session1'), isFalse);
      expect(manager.getUsersSessionIds(), contains('session1'));
    });

    test('joinUsersSession and getUsersSessionUsers', () {
      manager.createUsersSession('lounge');
      expect(manager.joinUsersSession('lounge', 'u1'), isTrue);
      expect(manager.joinUsersSession('lounge', 'u2'), isTrue);
      expect(manager.joinUsersSession('lounge', 'nonexistent'), isFalse);

      final users = manager.getUsersSessionUsers('lounge');
      expect(users.length, equals(2));
      expect(users.map((u) => u.id), containsAll(['u1', 'u2']));
    });

    test('leaveUsersSession', () {
      manager.joinUsersSession('main_session', 'u1');
      expect(manager.leaveUsersSession('main_session', 'u1'), isTrue);
      expect(manager.getUsersSessionUsers('main_session'), isEmpty);
      expect(manager.leaveUsersSession('main_session', 'u1'), isFalse);
    });

    test('clear resets session data', () {
      manager.joinUsersSession('sessionA', 'u1');
      manager.clear();
      expect(manager.getUsersSessionIds(), isEmpty);
      expect(manager.getUsersSessionUsers('sessionA'), isEmpty);
    });

    test('synchronously updates user properties in session', () {
      final sessionManager = NCLUsers();
      sessionManager.registerUser(
        NCLUserData(
          id: 'u1',
          name: 'Alice',
          initialProperties: {'status': 'active'},
        ),
      );
      sessionManager.registerUser(
        NCLUserData(
          id: 'u2',
          name: 'Bob',
          initialProperties: {'status': 'idle'},
        ),
      );
      sessionManager.createUsersSession('session1');
      sessionManager.joinUsersSession('session1', 'u1');
      sessionManager.joinUsersSession('session1', 'u2');

      final sessionUsers = sessionManager.getUsersSessionUsers('session1');
      expect(sessionUsers.length, equals(2));

      sessionManager.setUserProperty('u1', 'status', 'playing');
      expect(sessionManager.getUserProperty('u1', 'status'), equals('playing'));
    });

    test(
      'getSessionPropertyValues aggregates property values across session users',
      () {
        final sessionManager = NCLUsers();
        sessionManager.registerUser(
          NCLUserData(
            id: 'u1',
            name: 'Alice',
            initialProperties: {'lang': 'pt-BR', 'age': 30},
          ),
        );
        sessionManager.registerUser(
          NCLUserData(
            id: 'u2',
            name: 'Bob',
            initialProperties: {'lang': 'en-US'},
          ),
        );
        sessionManager.registerUser(
          NCLUserData(id: 'u3', name: 'Carol', initialProperties: {'age': 22}),
        );

        sessionManager.createUsersSession('session1');
        sessionManager.joinUsersSession('session1', 'u1');
        sessionManager.joinUsersSession('session1', 'u2');
        sessionManager.joinUsersSession('session1', 'u3');

        final langValues = sessionManager.getSessionPropertyValues(
          'session1',
          'lang',
        );
        expect(langValues.length, equals(2));
        expect(langValues['u1'], equals('pt-BR'));
        expect(langValues['u2'], equals('en-US'));

        final ageValues = sessionManager.getSessionPropertyValues(
          'session1',
          'age',
        );
        expect(ageValues.length, equals(2));
        expect(ageValues['u1'], equals(30));
        expect(ageValues['u3'], equals(22));
      },
    );

    test('removeUsersSession removes active session', () {
      final sessionManager = NCLUsers();
      sessionManager.createUsersSession('tempSession');
      expect(sessionManager.getUsersSessionIds(), contains('tempSession'));

      expect(sessionManager.removeUsersSession('tempSession'), isTrue);
      expect(
        sessionManager.getUsersSessionIds(),
        isNot(contains('tempSession')),
      );
      expect(sessionManager.removeUsersSession('nonExistent'), isFalse);
    });
  });

  group('Platform GINGA_USERS_DATA Environment Tests', () {
    test('loads single user from inline GINGA_USERS_DATA JSON map with ID', () {
      final xml = '<ncl><body><media id="m1"/></body></ncl>';
      final doc = NCLDocument.fromXML(
        xml,
        usersDataJson:
            '{"id": "u100", "name": "Alice", "properties": {"age": 30}}',
      );
      expect(doc.users.getUser('u100'), isNotNull);
      expect(doc.users.getUserProperty('u100', 'age'), equals(30));
    });

    test(
      'loads user properties from inline GINGA_USERS_DATA JSON map without ID',
      () {
        final xml = '<ncl><body><media id="m1"/></body></ncl>';
        final doc = NCLDocument.fromXML(
          xml,
          usersDataJson: '{"age": 45, "preferredLang": "en-US"}',
        );
        final active = doc.users.activeUser;
        expect(active, isNotNull);
        expect(active?.getProperty('age'), equals(45));
        expect(active?.getProperty('preferredLang'), equals('en-US'));
      },
    );

    test('loads list of users from inline GINGA_USERS_DATA JSON list', () {
      final xml = '<ncl><body><media id="m1"/></body></ncl>';
      final doc = NCLDocument.fromXML(
        xml,
        usersDataJson:
            '[{"id": "u201", "name": "Alice"}, {"id": "u202", "name": "Bob"}]',
      );
      expect(doc.users.getUser('u201'), isNotNull);
      expect(doc.users.getUser('u202'), isNotNull);
      expect(doc.users.allUsers.length, equals(2));
    });

    test('loads all required attributes', () {
      final xml = '<ncl><body><media id="m1"/></body></ncl>';
      final doc = NCLDocument.fromXML(
        xml,
        usersDataJson: '''
{
  "id": "uViewer1",
  "name": "Alice",
  "properties": {
    "nickname": "AliceNick",
    "parentalControl": true,
    "maxContentRating": "14",
    "avatar": "avatar.png",
    "audioLanguage": "pt",
    "closedCaptioningLanguage": "pt",
    "userInterfaceLanguage": "pt",
    "closedCaptioning": true,
    "closedSigning": false,
    "closedSigningSide": "left",
    "closedSigningWidth": 20,
    "audioDescription": false,
    "dialogEnhancement": false,
    "voiceGuidance": false
  }
}
''',
      );

      final user = doc.users.getUser('uViewer1');
      expect(user, isNotNull);
      expect(user!.id, equals('uViewer1'));
      expect(user.name, equals('Alice'));
      expect(user.getProperty('nickname'), equals('AliceNick'));
      expect(user.getProperty('parentalControl'), isTrue);
      expect(user.getProperty('maxContentRating'), equals('14'));
      expect(user.getProperty('avatar'), equals('avatar.png'));
      expect(user.getProperty('audioLanguage'), equals('pt'));
      expect(user.getProperty('closedCaptioningLanguage'), equals('pt'));
      expect(user.getProperty('userInterfaceLanguage'), equals('pt'));
      expect(user.getProperty('closedCaptioning'), isTrue);
      expect(user.getProperty('closedSigning'), isFalse);
      expect(user.getProperty('closedSigningSide'), equals('left'));
      expect(user.getProperty('closedSigningWidth'), equals(20));
      expect(user.getProperty('audioDescription'), isFalse);
      expect(user.getProperty('dialogEnhancement'), isFalse);
      expect(user.getProperty('voiceGuidance'), isFalse);
    });
  });
}
