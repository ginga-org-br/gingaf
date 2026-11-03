import 'dart:convert';

import 'package:gingacc/gingacc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Tv3wsClient Unit Tests', () {
    test('fetchCurrentUser parses TV 3.0 current user response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/tv3/current-service/users/current-user') {
          return http.Response(
            jsonEncode({
              'userId': 'user-tv30-100',
              'name': 'Carlos Silva',
              'attributes': {
                'age': 35,
                'favoriteGenre': 'Documentary',
                'closedCaptioning': true,
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = Tv3wsClient(
        baseUrl: 'http://localhost:44642',
        client: mockClient,
      );

      final user = await client.fetchCurrentUser();
      expect(user, isNotNull);
      expect(user!.id, 'user-tv30-100');
      expect(user.name, 'Carlos Silva');
      expect(user.getProperty('age'), 35);
      expect(user.getProperty('favoriteGenre'), 'Documentary');
      expect(user.getProperty('closedCaptioning'), true);
    });

    test('fetchUserList parses user IDs list', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/tv3/current-service/users/') {
          return http.Response(
            jsonEncode(['u1', 'u2', 'u3']),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = Tv3wsClient(
        baseUrl: 'http://localhost:44642',
        client: mockClient,
      );

      final users = await client.fetchUserList();
      expect(users, ['u1', 'u2', 'u3']);
    });

    test('fetchUserAttributes returns user attributes map', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/tv3/current-service/users/user-42') {
          return http.Response(
            jsonEncode({'nickname': 'Bia', 'language': 'por'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = Tv3wsClient(
        baseUrl: 'http://localhost:44642',
        client: mockClient,
      );

      final attrs = await client.fetchUserAttributes('user-42');
      expect(attrs, isNotNull);
      expect(attrs!['nickname'], 'Bia');
      expect(attrs['language'], 'por');
    });

    test('syncWithGingaCC updates GingaCC users and systemVariables', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/tv3/current-service/users/current-user') {
          return http.Response(
            jsonEncode({
              'userId': 'usr-active-01',
              'name': 'Mariana',
              'attributes': {
                'age': 29,
                'theme': 'dark',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = Tv3wsClient(
        baseUrl: 'http://localhost:44642',
        client: mockClient,
      );

      final gingacc = GingaCC();
      final success = await client.syncWithGingaCC(gingacc);

      expect(success, isTrue);
      expect(gingacc.config.users.currentUser?.id, 'usr-active-01');
      expect(gingacc.config.users.currentUser?.name, 'Mariana');
      expect(gingacc.config.systemVariables['currentUser'], 'usr-active-01');
      expect(gingacc.config.systemVariables['user.id'], 'usr-active-01');
      expect(gingacc.config.systemVariables['user.name'], 'Mariana');
      expect(gingacc.config.systemVariables['user.age'], '29');
      expect(gingacc.config.systemVariables['user.theme'], 'dark');
    });

    test('fetchManifest returns advertised headers', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/manifest') {
          return http.Response(
            '',
            200,
            headers: {
              'server-baseurl': '192.168.1.50:44642',
              'device-friendlyname': 'TV 3.0 Living Room',
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = Tv3wsClient(
        baseUrl: 'http://localhost:44642',
        client: mockClient,
      );

      final headers = await client.fetchManifest();
      expect(headers, isNotNull);
      expect(headers!['server-baseurl'], '192.168.1.50:44642');
      expect(headers['device-friendlyname'], 'TV 3.0 Living Room');
    });
  });
}
