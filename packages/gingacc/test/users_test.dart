import 'package:gingacc/users.dart';
import 'package:test/test.dart';

void main() {
  group('Users API Core Tests', () {
    test('UserData stores and updates properties correctly', () {
      final user = UserData(
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

    test('Users registered', () {
      final manager = Users();

      final user1 = UserData(id: 'u1', name: 'User One');
      final user2 = UserData(id: 'u2', name: 'User Two');

      manager.registerUser(user1);
      manager.registerUser(user2);

      expect(manager.allUsers.length, equals(2));
      expect(manager.currentUser?.id, equals('u1'));

      manager.setCurrentUser('u2');
      expect(manager.currentUser?.id, equals('u2'));
      expect(manager.getUser('u1')?.name, equals('User One'));
    });

    test('Users gets and sets user properties synchronously', () {
      final manager = Users();
      final user = UserData(id: 'u1', name: 'User One');
      manager.registerUser(user);

      expect(manager.setUserProperty('u1', 'preferredQuality', 'HD'), isTrue);
      expect(manager.getUserProperty('u1', 'preferredQuality'), equals('HD'));

      manager.removeUser('u1');
      expect(manager.getUser('u1'), isNull);
      expect(manager.currentUser, isNull);
    });

    test('loads user data via JSON param', () {
      final manager = Users();
      const usersDataJson =
          '{"id": "uRemote1", "name": "Remote User", "properties": {"level": "premium"}}';
      manager.loadUserData(usersDataJson);
      expect(manager.getUser('uRemote1'), isNotNull);
      expect(manager.getUserProperty('uRemote1', 'level'), equals('premium'));
    });

    test('handles invalid or empty JSON gracefully in loadUserData', () {
      final manager = Users();
      expect(
        () => manager.loadUserData('invalid json format {{{'),
        throwsFormatException,
      );
      expect(() => manager.loadUserData(''), returnsNormally);
      expect(() => manager.loadUserData('   '), returnsNormally);
      expect(manager.allUsers, isEmpty);
    });
  });

  group('UserProfile Query Evaluation Tests', () {
    test('evaluates profile query with numeric comparison operators', () {
      final userAdult = UserData(
        id: 'u1',
        name: 'Adult',
        initialProperties: {'age': 20, 'rating': 4.5},
      );
      final userMinor = UserData(
        id: 'u2',
        name: 'Minor',
        initialProperties: {'age': 15, 'rating': 2.0},
      );

      final profileGte = UserProfileQuery(
        {'attribute': 'age', 'comparator': 'gte', 'value': '18'},
      );

      final profileLt = UserProfileQuery(
        {'attribute': 'age', 'comparator': 'lt', 'value': '18'},
      );

      final profileGt = UserProfileQuery(
        {'attribute': 'rating', 'comparator': 'gt', 'value': '3.0'},
      );

      final profileLte = UserProfileQuery(
        {'attribute': 'rating', 'comparator': 'lte', 'value': '2.0'},
      );

      final profileNe = UserProfileQuery(
        {'attribute': 'age', 'comparator': 'neq', 'value': '15'},
      );

      expect(profileGte.matches(userAdult), isTrue);
      expect(profileGte.matches(userMinor), isFalse);

      expect(profileLt.matches(userAdult), isFalse);
      expect(profileLt.matches(userMinor), isTrue);

      expect(profileGt.matches(userAdult), isTrue);
      expect(profileGt.matches(userMinor), isFalse);

      expect(profileLte.matches(userMinor), isTrue);

      expect(profileNe.matches(userAdult), isTrue);
      expect(profileNe.matches(userMinor), isFalse);
    });

    test('evaluates profile query with nested AND and OR operators', () {
      final user = UserData(
        id: 'u1',
        name: 'Alice',
        initialProperties: {'age': 25, 'gender': 'female', 'lang': 'pt'},
      );

      final profileAnd = UserProfileQuery(
        {
          'operator': 'and',
          'rules': [
            {'attribute': 'age', 'comparator': 'gte', 'value': '18'},
            {'attribute': 'gender', 'comparator': 'eq', 'value': 'female'},
          ],
        },
      );

      final profileOr = UserProfileQuery(
        {
          'operator': 'or',
          'rules': [
            {'attribute': 'lang', 'comparator': 'eq', 'value': 'en'},
            {'attribute': 'lang', 'comparator': 'eq', 'value': 'pt'},
          ],
        },
      );

      expect(profileAnd.matches(user), isTrue);
      expect(profileOr.matches(user), isTrue);
    });

    test(
        'evaluates profile directly with evaluateProfile and evaluateProfileForUser',
        () {
      final users = Users();
      final u1 = UserData(
        id: 'u1',
        name: 'User 1',
        initialProperties: {'tier': 'gold', 'credits': 100},
      );
      final u2 = UserData(
        id: 'u2',
        name: 'User 2',
        initialProperties: {'tier': 'silver', 'credits': 20},
      );

      users.registerUser(u1);
      users.registerUser(u2);

      final profileGold = UserProfileQuery(
        {'attribute': 'tier', 'comparator': 'eq', 'value': 'gold'},
      );
      final profileVip = UserProfileQuery(
        {'attribute': 'credits', 'comparator': 'gte', 'value': '500'},
      );

      expect(users.evaluateProfile(profileGold), isTrue);
      expect(users.evaluateProfile(profileVip), isFalse);
      expect(users.evaluateProfileForUser(profileGold, 'u1'), isTrue);
      expect(users.evaluateProfileForUser(profileGold, 'u2'), isFalse);
      expect(users.evaluateProfileForUser(profileGold, 'nonexistent'), isFalse);
    });

    test(
        'evaluates profile for specific user ID and retrieves all matching users for profile',
        () {
      final users = Users();
      final u1 = UserData(
        id: 'u1',
        name: 'User 1',
        initialProperties: {'role': 'admin', 'points': 100},
      );
      final u2 = UserData(
        id: 'u2',
        name: 'User 2',
        initialProperties: {'role': 'guest', 'points': 50},
      );
      final u3 = UserData(
        id: 'u3',
        name: 'User 3',
        initialProperties: {'role': 'admin', 'points': 200},
      );

      users.registerUser(u1);
      users.registerUser(u2);
      users.registerUser(u3);

      final profileAdmin = UserProfileQuery(
        {'attribute': 'role', 'comparator': 'eq', 'value': 'admin'},
      );

      expect(users.evaluateProfileForUser(profileAdmin, 'u1'), isTrue);
      expect(users.evaluateProfileForUser(profileAdmin, 'u2'), isFalse);
      expect(users.evaluateProfileForUser(profileAdmin, 'u3'), isTrue);
      expect(
          users.evaluateProfileForUser(profileAdmin, 'nonexistent'), isFalse);

      final matchingAdmins = users.getMatchingUsersForProfile(profileAdmin);
      expect(matchingAdmins, containsAll([u1, u3]));
      expect(matchingAdmins, isNot(contains(u2)));
      expect(users.getMatchingUsersForProfile(profileAdmin).length, equals(2));
    });

    test('supports UserProfileQuery fromJson and toJson serialization', () {
      final profileJson = {
        'query': {'attribute': 'age', 'comparator': 'gte', 'value': '18'},
      };

      final profile = UserProfileQuery.fromJson(profileJson);
      expect(profile.query['attribute'], equals('age'));

      final userAdult = UserData(
        id: 'u1',
        name: 'Adult',
        initialProperties: {'age': 20},
      );
      expect(profile.matches(userAdult), isTrue);

      final exportedJson = profile.toJson();
      expect(exportedJson, equals(profileJson['query']));

      final flatProfileJson = {
        'attribute': 'tier',
        'comparator': 'eq',
        'value': 'gold',
      };
      final profileFlat = UserProfileQuery.fromJson(flatProfileJson);
      expect(profileFlat.query['attribute'], equals('tier'));
    });

    test(
        'supports user property removal and clearing across UserData and Users',
        () {
      final user = UserData(
        id: 'u1',
        name: 'User 1',
        initialProperties: {'age': 30, 'city': 'Rio', 'status': 'active'},
      );
      final users = Users();
      users.registerUser(user);
      expect(user.hasProperty('city'), isTrue);
      expect(user.getProperty('city'), equals('Rio'));

      users.clear();
      expect(users.allUsers, isEmpty);
      expect(users.currentUser, isNull);
    });

    test('evaluates neq comparator and Users batch helper methods', () {
      final u1 = UserData(
        id: 'u1',
        name: 'Alice',
        initialProperties: {
          'role': 'admin',
          'city': 'San Francisco',
          'tags': 'flutter,dart,ncl',
        },
      );
      final u2 = UserData(
        id: 'u2',
        name: 'Bob',
        initialProperties: {
          'role': 'guest',
          'city': 'San Jose',
          'tags': 'python,ncl',
        },
      );

      final users = Users();
      users.registerUsers([u1, u2]);

      expect(users.allUsers.length, equals(2));
      expect(users.getCurrentUserProperty('role'), equals('admin'));

      final admins = users.getUsersByProperty('role', 'admin');
      expect(admins, equals([u1]));

      final pNeq = UserProfileQuery(
        {'attribute': 'role', 'comparator': 'neq', 'value': 'guest'},
      );

      expect(pNeq.matches(u1), isTrue);
      expect(pNeq.matches(u2), isFalse);
      expect(users.getMatchingUsersForProfile(pNeq).length, equals(1));
    });

    test('diffNewCurrentUser computes property differences accurately', () {
      final u1 = UserData(
        id: 'u1',
        name: 'Alice',
        initialProperties: {'age': 30, 'gender': 'female', 'lang': 'pt'},
      );
      final u2 = UserData(
        id: 'u2',
        name: 'Bob',
        initialProperties: {'age': 30, 'gender': 'male', 'country': 'BR'},
      );

      final users = Users();
      users.registerUsers([u1, u2]);

      final diff = users.diffNewCurrentUser('u2');
      expect(diff['currentUser'], equals('u2'));
      expect(diff['system.user'], equals('u2'));
      expect(diff['id'], equals('u2'));
      expect(diff['name'], equals('Bob'));
      expect(diff['gender'], equals('male'));
      expect(diff['lang'], equals(''));
      expect(diff['country'], equals('BR'));
      expect(diff.containsKey('age'), isFalse);

      users.setCurrentUser('u2');
      final sameDiff = users.diffNewCurrentUser('u2');
      expect(sameDiff, isEmpty);
    });
  });
}
