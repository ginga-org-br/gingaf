import 'package:ncl_doc/users.dart';
import 'package:test/test.dart';

void main() {
  group('NCL Users API Core Tests', () {
    test('NCLUser stores and updates properties correctly', () {
      final user = NCLUser(
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
      final manager = Users();

      final user1 = NCLUser(id: 'u1', name: 'User One');
      final user2 = NCLUser(id: 'u2', name: 'User Two');

      manager.registerUser(user1);
      manager.registerUser(user2);

      expect(manager.allUsers.length, equals(2));
      expect(manager.activeUser?.id, equals('u1'));

      manager.setActiveUser('u2');
      expect(manager.activeUser?.id, equals('u2'));
      expect(manager.getUser('u1')?.name, equals('User One'));
    });

    test('Users gets and sets user properties synchronously', () {
      final manager = Users();
      final user = NCLUser(id: 'u1', name: 'User One');
      manager.registerUser(user);

      expect(manager.setUserProperty('u1', 'preferredQuality', 'HD'), isTrue);
      expect(manager.getUserProperty('u1', 'preferredQuality'), equals('HD'));

      manager.removeUser('u1');
      expect(manager.getUser('u1'), isNull);
      expect(manager.activeUser, isNull);
    });
  });

  group('Multi-Document Users Synchronization', () {
    test('synchronizes properties synchronously across document managers', () {
      final doc1Manager = Users();
      final doc2Manager = Users();

      doc1Manager.registerUser(NCLUser(id: 'u1', name: 'Bob', initialProperties: {'lang': 'pt-BR'}));
      doc2Manager.syncFrom(doc1Manager);

      expect(doc2Manager.getUser('u1')?.name, equals('Bob'));
      expect(doc2Manager.getUserProperty('u1', 'lang'), equals('pt-BR'));

      doc1Manager.setUserProperty('u1', 'lang', 'en-US');
      doc2Manager.syncFrom(doc1Manager);

      expect(doc2Manager.getUserProperty('u1', 'lang'), equals('en-US'));
    });
  });

  group('NCL User Serialization Tests', () {
    test('NCLUser serializes to JSON and deserializes from JSON', () {
      final user = NCLUser(
        id: 'user1',
        name: 'Alice',
        initialProperties: {'age': 25, 'lang': 'pt-BR'},
      );

      final json = user.toJson();
      expect(json['id'], equals('user1'));
      expect(json['name'], equals('Alice'));
      expect(json['properties']['age'], equals(25));
      expect(json['properties']['lang'], equals('pt-BR'));

      final restoredUser = NCLUser.fromJson(json);
      expect(restoredUser.id, equals('user1'));
      expect(restoredUser.name, equals('Alice'));
      expect(restoredUser.getProperty('age'), equals(25));
      expect(restoredUser.getProperty('lang'), equals('pt-BR'));
    });

    test('Users exports and imports users JSON list', () {
      final manager = Users();
      manager.registerUser(NCLUser(
        id: 'u1',
        name: 'Bob',
        initialProperties: {'device': 'tv'},
      ));
      manager.registerUser(NCLUser(
        id: 'u2',
        name: 'Carol',
        initialProperties: {'device': 'mobile'},
      ));

      final exported = manager.exportUsers();
      expect(exported.length, equals(2));

      final newManager = Users();
      newManager.importUsers(exported);

      expect(newManager.allUsers.length, equals(2));
      expect(newManager.getUserProperty('u1', 'device'), equals('tv'));
      expect(newManager.getUserProperty('u2', 'device'), equals('mobile'));
    });
  });

  group('NCL Users Session Management Tests', () {
    late Users manager;

    setUp(() {
      manager = Users();
      manager.registerUser(NCLUser(id: 'u1', name: 'Alice'));
      manager.registerUser(NCLUser(id: 'u2', name: 'Bob'));
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
      final sessionManager = Users();
      sessionManager.registerUser(NCLUser(id: 'u1', name: 'Alice', initialProperties: {'status': 'active'}));
      sessionManager.registerUser(NCLUser(id: 'u2', name: 'Bob', initialProperties: {'status': 'idle'}));
      sessionManager.createUsersSession('session1');
      sessionManager.joinUsersSession('session1', 'u1');
      sessionManager.joinUsersSession('session1', 'u2');

      final sessionUsers = sessionManager.getUsersSessionUsers('session1');
      expect(sessionUsers.length, equals(2));

      sessionManager.setUserProperty('u1', 'status', 'playing');
      expect(sessionManager.getUserProperty('u1', 'status'), equals('playing'));
    });

    test('getSessionPropertyValues aggregates property values across session users', () {
      final sessionManager = Users();
      sessionManager.registerUser(NCLUser(id: 'u1', name: 'Alice', initialProperties: {'lang': 'pt-BR', 'age': 30}));
      sessionManager.registerUser(NCLUser(id: 'u2', name: 'Bob', initialProperties: {'lang': 'en-US'}));
      sessionManager.registerUser(NCLUser(id: 'u3', name: 'Carol', initialProperties: {'age': 22}));

      sessionManager.createUsersSession('session1');
      sessionManager.joinUsersSession('session1', 'u1');
      sessionManager.joinUsersSession('session1', 'u2');
      sessionManager.joinUsersSession('session1', 'u3');

      final langValues = sessionManager.getSessionPropertyValues('session1', 'lang');
      expect(langValues.length, equals(2));
      expect(langValues['u1'], equals('pt-BR'));
      expect(langValues['u2'], equals('en-US'));

      final ageValues = sessionManager.getSessionPropertyValues('session1', 'age');
      expect(ageValues.length, equals(2));
      expect(ageValues['u1'], equals(30));
      expect(ageValues['u3'], equals(22));
    });

    test('removeUsersSession removes active session', () {
      final sessionManager = Users();
      sessionManager.createUsersSession('tempSession');
      expect(sessionManager.getUsersSessionIds(), contains('tempSession'));

      expect(sessionManager.removeUsersSession('tempSession'), isTrue);
      expect(sessionManager.getUsersSessionIds(), isNot(contains('tempSession')));
      expect(sessionManager.removeUsersSession('nonExistent'), isFalse);
    });
  });
}

