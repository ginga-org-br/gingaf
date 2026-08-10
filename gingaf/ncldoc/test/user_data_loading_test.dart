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



  group('Platform USERS_DATA Environment Tests', () {
    test('loads single user from inline USERS_DATA JSON map with ID', () {
      final xml = '<ncl><body><media id="m1"/></body></ncl>';
      final doc = NCLDocument.fromContent(
        xml,
        userData: '{"id": "u100", "name": "Alice", "properties": {"age": 30}}',
      );
      expect(doc.users.getUser('u100'), isNotNull);
      expect(doc.users.getUserProperty('u100', 'age'), equals(30));
    });

    test(
      'loads user properties from inline USERS_DATA JSON map without ID',
      () {
        final xml = '<ncl><body><media id="m1"/></body></ncl>';
        final doc = NCLDocument.fromContent(
          xml,
          userData: '{"age": 45, "preferredLang": "en-US"}',
        );
        final active = doc.users.activeUser;
        expect(active, isNotNull);
        expect(active?.getProperty('age'), equals(45));
        expect(active?.getProperty('preferredLang'), equals('en-US'));
      },
    );

    test('loads list of users from inline USERS_DATA JSON list', () {
      final xml = '<ncl><body><media id="m1"/></body></ncl>';
      final doc = NCLDocument.fromContent(
        xml,
        userData:
            '[{"id": "u201", "name": "Alice"}, {"id": "u202", "name": "Bob"}]',
      );
      expect(doc.users.getUser('u201'), isNotNull);
      expect(doc.users.getUser('u202'), isNotNull);
      expect(doc.users.allUsers.length, equals(2));
    });

    test('loads all required attributes', () {
      final xml = '<ncl><body><media id="m1"/></body></ncl>';
      final doc = NCLDocument.fromContent(
        xml,
        userData: '''
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

    test('loads user data via JSON param', () {
      final manager = NCLUsers();
      const usersDataJson =
          '{"id": "uRemote1", "name": "Remote User", "properties": {"level": "premium"}}';
      manager.loadUserData(usersDataJson);
      expect(manager.getUser('uRemote1'), isNotNull);
      expect(manager.getUserProperty('uRemote1', 'level'), equals('premium'));
    });

    test('handles invalid or empty JSON gracefully in loadUserData', () {
      final manager = NCLUsers();
      expect(
        () => manager.loadUserData('invalid json format {{{'),
        throwsFormatException,
      );
      expect(() => manager.loadUserData(''), returnsNormally);
      expect(() => manager.loadUserData('   '), returnsNormally);
      expect(manager.allUsers, isEmpty);
    });
  });
}
