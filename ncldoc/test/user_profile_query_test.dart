import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCL User Profile Query Evaluation Tests', () {
    test('evaluates profile query with numeric comparison operators', () {
      final userAdult = NCLUserData(
        id: 'u1',
        name: 'Adult',
        initialProperties: {'age': 20, 'rating': 4.5},
      );
      final userMinor = NCLUserData(
        id: 'u2',
        name: 'Minor',
        initialProperties: {'age': 15, 'rating': 2.0},
      );

      final profileGte = NCLUserProfile(
        id: 'pGte',
        query: {'attribute': 'age', 'comparator': 'gte', 'value': '18'},
      );

      final profileLt = NCLUserProfile(
        id: 'pLt',
        query: {'attribute': 'age', 'comparator': 'lt', 'value': '18'},
      );

      final profileGt = NCLUserProfile(
        id: 'pGt',
        query: {'attribute': 'rating', 'comparator': 'gt', 'value': '3.0'},
      );

      final profileLte = NCLUserProfile(
        id: 'pLte',
        query: {'attribute': 'rating', 'comparator': 'lte', 'value': '2.0'},
      );

      final profileNe = NCLUserProfile(
        id: 'pNe',
        query: {'attribute': 'age', 'comparator': 'ne', 'value': '15'},
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
      final user = NCLUserData(
        id: 'u1',
        name: 'Alice',
        initialProperties: {'age': 25, 'gender': 'female', 'lang': 'pt'},
      );

      final profileAnd = NCLUserProfile(
        id: 'pAnd',
        query: {
          'operator': 'and',
          'rules': [
            {'attribute': 'age', 'comparator': 'gte', 'value': '18'},
            {'attribute': 'gender', 'comparator': 'eq', 'value': 'female'},
          ],
        },
      );

      final profileOr = NCLUserProfile(
        id: 'pOr',
        query: {
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

    test('registers profiles in NCLUsers and evaluates profiles against all registered users', () {
      final users = NCLUsers();
      final u1 = NCLUserData(
        id: 'u1',
        name: 'User 1',
        initialProperties: {'tier': 'gold', 'credits': 100},
      );
      final u2 = NCLUserData(
        id: 'u2',
        name: 'User 2',
        initialProperties: {'tier': 'silver', 'credits': 20},
      );

      users.registerUser(u1);
      users.registerUser(u2);

      final profileGold = NCLUserProfile(
        id: 'pGold',
        query: {'attribute': 'tier', 'comparator': 'eq', 'value': 'gold'},
      );
      final profileVip = NCLUserProfile(
        id: 'pVip',
        query: {'attribute': 'credits', 'comparator': 'gte', 'value': '500'},
      );

      users.registerProfile(profileGold);
      users.registerProfile(profileVip);

      expect(users.getProfile('pGold'), equals(profileGold));
      expect(users.getProfile('pVip'), equals(profileVip));

      expect(users.evaluateProfile('pGold'), isTrue);
      expect(users.evaluateProfile('pVip'), isFalse);
      expect(users.evaluateProfile('nonExistent'), isFalse);
    });

    test('supports allProfiles, removeProfile, and clearing profiles on NCLUsers.clear()', () {
      final users = NCLUsers();
      final p1 = NCLUserProfile(
        id: 'p1',
        query: {'attribute': 'age', 'comparator': 'gte', 'value': '18'},
      );
      final p2 = NCLUserProfile(
        id: 'p2',
        query: {'attribute': 'lang', 'comparator': 'eq', 'value': 'en'},
      );

      users.registerProfile(p1);
      users.registerProfile(p2);

      expect(users.allProfiles, containsAll([p1, p2]));

      users.clear();
      expect(users.allProfiles, isEmpty);
      expect(users.getProfile('p2'), isNull);
    });

    test('evaluates nested AND/OR rules, string comparisons, and src property in NCLUserProfile', () {
      final user = NCLUserData(
        id: 'u1',
        name: 'Dave',
        initialProperties: {'country': 'Brazil', 'city': 'Rio'},
      );

      final profileNested = NCLUserProfile(
        id: 'pNested',
        src: 'http://example.com/profiles/pNested.xml',
        query: {
          'operator': 'or',
          'rules': [
            {
              'operator': 'and',
              'rules': [
                {'attribute': 'country', 'comparator': 'eq', 'value': 'Brazil'},
                {'attribute': 'city', 'comparator': 'gt', 'value': 'Alpha'},
              ],
            },
          ],
        },
      );

      expect(profileNested.src, equals('http://example.com/profiles/pNested.xml'));
      expect(profileNested.matches(user), isTrue);
    });

    test('evaluates profile queries with uppercase AND/OR keys, empty rules, missing attributes, and dynamic user updates', () {
      final user = NCLUserData(
        id: 'u1',
        name: 'Eve',
        initialProperties: {'level': 'beginner'},
      );

      final profileUppercaseAnd = NCLUserProfile(
        id: 'pUpperAnd',
        query: {
          'AND': [
            {'attribute': 'level', 'comparator': 'eq', 'value': 'beginner'},
          ],
        },
      );

      final profileUppercaseOr = NCLUserProfile(
        id: 'pUpperOr',
        query: {
          'OR': [
            {'attribute': 'level', 'comparator': 'eq', 'value': 'expert'},
            {'attribute': 'level', 'comparator': 'eq', 'value': 'beginner'},
          ],
        },
      );

      final profileEmptyOr = NCLUserProfile(
        id: 'pEmptyOr',
        query: {
          'OR': [],
        },
      );

      final profileMissingAttr = NCLUserProfile(
        id: 'pMissing',
        query: {'attribute': 'nonexistent', 'comparator': 'eq', 'value': 'val'},
      );

      expect(profileUppercaseAnd.matches(user), isTrue);
      expect(profileUppercaseOr.matches(user), isTrue);
      expect(profileEmptyOr.matches(user), isFalse);
      expect(profileMissingAttr.matches(user), isFalse);

      final users = NCLUsers();
      users.registerUser(user);

      final profilePro = NCLUserProfile(
        id: 'pPro',
        query: {'attribute': 'level', 'comparator': 'eq', 'value': 'pro'},
      );
      users.registerProfile(profilePro);

      expect(users.evaluateProfile('pPro'), isFalse);

      users.setUserProperty('u1', 'level', 'pro');
      expect(users.evaluateProfile('pPro'), isTrue);
    });

    test('evaluates profile for specific user ID and retrieves all matching users for profile', () {
      final users = NCLUsers();
      final u1 = NCLUserData(id: 'u1', name: 'User 1', initialProperties: {'role': 'admin', 'points': 100});
      final u2 = NCLUserData(id: 'u2', name: 'User 2', initialProperties: {'role': 'guest', 'points': 50});
      final u3 = NCLUserData(id: 'u3', name: 'User 3', initialProperties: {'role': 'admin', 'points': 200});

      users.registerUser(u1);
      users.registerUser(u2);
      users.registerUser(u3);

      final profileAdmin = NCLUserProfile(
        id: 'pAdmin',
        query: {'attribute': 'role', 'comparator': 'eq', 'value': 'admin'},
      );

      users.registerProfile(profileAdmin);

      expect(users.evaluateProfileForUser('pAdmin', 'u1'), isTrue);
      expect(users.evaluateProfileForUser('pAdmin', 'u2'), isFalse);
      expect(users.evaluateProfileForUser('pAdmin', 'u3'), isTrue);
      expect(users.evaluateProfileForUser('pAdmin', 'nonexistent'), isFalse);
      expect(users.evaluateProfileForUser('nonexistentProfile', 'u1'), isFalse);

      final matchingAdmins = users.getMatchingUsersForProfile('pAdmin');
      expect(matchingAdmins, containsAll([u1, u3]));
      expect(matchingAdmins, isNot(contains(u2)));
      expect(users.getMatchingUsersForProfile('nonexistentProfile'), isEmpty);
    });

    test('supports user property removal and clearing across NCLUserData and NCLUsers', () {
      final user = NCLUserData(
        id: 'u1',
        name: 'User 1',
        initialProperties: {'age': 30, 'city': 'Rio', 'status': 'active'},
      );
      final users = NCLUsers();
      users.registerUser(user);
      expect(user.hasProperty('city'), isTrue);
      expect(user.getProperty('city'), equals('Rio'));
    });

    test('supports NCLUserProfile fromJson and toJson serialization', () {
      final profileJson = {
        'id': 'pSer1',
        'src': 'http://example.com/pSer1.xml',
        'query': {
          'attribute': 'age',
          'comparator': 'gte',
          'value': '18',
        },
      };

      final profile = NCLUserProfile.fromJson(profileJson);
      expect(profile.id, equals('pSer1'));
      expect(profile.src, equals('http://example.com/pSer1.xml'));
      expect(profile.query['attribute'], equals('age'));

      final userAdult = NCLUserData(id: 'u1', name: 'Adult', initialProperties: {'age': 20});
      expect(profile.matches(userAdult), isTrue);

      final exportedJson = profile.toJson();
      expect(exportedJson['id'], equals('pSer1'));
      expect(exportedJson['src'], equals('http://example.com/pSer1.xml'));
      expect(exportedJson['query'], equals(profileJson['query']));

      final flatProfileJson = {
        'id': 'pSer2',
        'attribute': 'tier',
        'comparator': 'eq',
        'value': 'gold',
      };
      final profileFlat = NCLUserProfile.fromJson(flatProfileJson);
      expect(profileFlat.id, equals('pSer2'));
      expect(profileFlat.src, isNull);
      expect(profileFlat.query['attribute'], equals('tier'));
    });

    test('evaluates profile query with built-in id and name attributes and exports user data', () {
      final users = NCLUsers();
      final u1 = NCLUserData(id: 'usr_001', name: 'Alice Smith', initialProperties: {'role': 'admin'});
      final u2 = NCLUserData(id: 'usr_002', name: 'Bob Jones', initialProperties: {'role': 'user'});
      users.registerUser(u1);
      users.registerUser(u2);

      expect(u1.getProperty('id'), equals('usr_001'));
      expect(u1.getProperty('name'), equals('Alice Smith'));
      expect(u1.hasProperty('id'), isTrue);
      expect(u1.hasProperty('name'), isTrue);

      final pId = NCLUserProfile(id: 'pId', query: {'attribute': 'id', 'comparator': 'eq', 'value': 'usr_001'});
      final pName = NCLUserProfile(id: 'pName', query: {'attribute': 'name', 'comparator': 'eq', 'value': 'Alice Smith'});

      expect(pId.matches(u1), isTrue);
      expect(pId.matches(u2), isFalse);
      expect(pName.matches(u1), isTrue);
      expect(pName.matches(u2), isFalse);
    });

    test('evaluates profiles and tests findProfilesForUser', () {
      final user = NCLUserData(
        id: 'u100',
        name: 'Charlie Brown',
        initialProperties: {
          'city': 'San Francisco',
          'email': 'charlie@example.com',
          'category': 'vip',
        },
      );

      final pContains = NCLUserProfile(id: 'p1', query: {'attribute': 'email', 'comparator': 'eq', 'value': 'charlie@example.com'});
      final pStartsWith = NCLUserProfile(id: 'p2', query: {'attribute': 'city', 'comparator': 'eq', 'value': 'San Francisco'});
      final pEndsWith = NCLUserProfile(id: 'p3', query: {'attribute': 'city', 'comparator': 'eq', 'value': 'San Francisco'});
      final pInList = NCLUserProfile(id: 'p4', query: {'attribute': 'category', 'comparator': 'eq', 'value': 'vip'});
      final pInCsv = NCLUserProfile(id: 'p5', query: {'attribute': 'category', 'comparator': 'eq', 'value': 'vip'});
      final pNoMatch = NCLUserProfile(id: 'p6', query: {'attribute': 'category', 'comparator': 'eq', 'value': 'basic'});

      expect(pContains.matches(user), isTrue);
      expect(pStartsWith.matches(user), isTrue);
      expect(pEndsWith.matches(user), isTrue);
      expect(pInList.matches(user), isTrue);
      expect(pInCsv.matches(user), isTrue);
      expect(pNoMatch.matches(user), isFalse);

      final users = NCLUsers();
      users.registerProfile(pContains);
      users.registerProfile(pStartsWith);
      users.registerProfile(pEndsWith);
      users.registerProfile(pNoMatch);

      final matchedProfiles = users.findProfilesForUser(user);
      expect(matchedProfiles, containsAll([pContains, pStartsWith, pEndsWith]));
      expect(matchedProfiles, isNot(contains(pNoMatch)));
    });

    test('imports and exports profiles in NCLUsers', () {
      final users = NCLUsers();
      final profilesJson = [
        {
          'id': 'p1',
          'src': 'profiles.json#p1',
          'query': {'attribute': 'age', 'comparator': 'gte', 'value': '18'},
        },
        {
          'id': 'p2',
          'query': {'attribute': 'tier', 'comparator': 'eq', 'value': 'gold'},
        },
      ];

      users.importProfiles(profilesJson);
      expect(users.allProfiles.length, equals(2));
      expect(users.getProfile('p1')?.src, equals('profiles.json#p1'));

      final exported = users.exportProfiles();
      expect(exported.length, equals(2));
      expect(exported.first['id'], equals('p1'));
      expect(exported.first['src'], equals('profiles.json#p1'));
    });

    test('NCLDocument uses custom loadContent callback for user profile', () async {
      final xml = '<ncl><head><userBase><userProfile id="p1" src="profile.json"/></userBase></head><body id="body"></body></ncl>';
      final doc = NCLDocument.fromContent(
        xml,
        contentLoader: _MockProfileContentLoader(),
      );
      await doc.loadUserProfiles();

      expect(doc.users.getProfile('p1'), isNotNull);
      expect(doc.users.getProfile('p1')?.query['attribute'], equals('role'));
    });

    test('evaluates neq comparator, string comparators, and NCLUsers batch helper methods', () {
      final u1 = NCLUserData(
        id: 'u1',
        name: 'Alice',
        initialProperties: {'role': 'admin', 'city': 'San Francisco', 'tags': 'flutter,dart,ncl'},
      );
      final u2 = NCLUserData(
        id: 'u2',
        name: 'Bob',
        initialProperties: {'role': 'guest', 'city': 'San Jose', 'tags': 'python,ncl'},
      );

      final users = NCLUsers();
      users.registerUsers([u1, u2]);

      expect(users.allUsers.length, equals(2));
      expect(users.getActiveUserProperty('role'), equals('admin'));

      final admins = users.getUsersByProperty('role', 'admin');
      expect(admins, equals([u1]));

      final pNeq = NCLUserProfile(
        id: 'pNeq',
        query: {'attribute': 'role', 'comparator': 'neq', 'value': 'guest'},
      );

      users.registerProfile(pNeq);

      expect(pNeq.matches(u1), isTrue);
      expect(pNeq.matches(u2), isFalse);

      expect(users.countMatchingUsers('pNeq'), equals(1));
    });
  });
}

class _MockProfileContentLoader extends ContentLoader {
  @override
  bool exists(Uri uri) => true;

  @override
  Future<String?> load(Uri uri) async {
    if (uri.toString().endsWith('profile.json')) {
      return '{"attribute":"role","comparator":"eq","value":"admin"}';
    }
    return null;
  }
}





