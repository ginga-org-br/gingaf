import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'gingacc.dart';

final _logger = Logger('tv3ws-client');

/// Client for TV 3.0 WebServices (ABNT NBR 25608 Annex C).
class Tv3wsClient {
  final String baseUrl;
  final http.Client _client;

  Tv3wsClient({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? 'http://127.0.0.1:44642')
            .replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  /// Obtains the current active user from TV 3.0 WebServices (C.6.14.3).
  Future<UserData?> fetchCurrentUser([
    String serviceContextId = 'current-service',
  ]) async {
    try {
      final uri =
          Uri.parse('$baseUrl/tv3/$serviceContextId/users/current-user');
      final res = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final userId = map['userId']?.toString() ??
              map['id']?.toString() ??
              map['user_id']?.toString() ??
              '';
          final name =
              map['name']?.toString() ?? map['nickname']?.toString() ?? userId;
          final attributes = map['attributes'];
          final props = <String, dynamic>{};
          if (attributes is Map) {
            props.addAll(Map<String, dynamic>.from(attributes));
          }
          map.forEach((key, val) {
            if (key != 'userId' &&
                key != 'id' &&
                key != 'user_id' &&
                key != 'name' &&
                key != 'nickname' &&
                key != 'attributes') {
              props[key] = val;
            }
          });
          return UserData(id: userId, name: name, initialProperties: props);
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 current user: $e');
    }
    return null;
  }

  /// Obtains the list of available user IDs (C.6.14.1).
  Future<List<String>> fetchUserList([
    String serviceContextId = 'current-service',
  ]) async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/$serviceContextId/users/');
      final res = await _client.post(uri, headers: {
        'Accept': 'application/json',
      });
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        } else if (decoded is Map && decoded['users'] is List) {
          return (decoded['users'] as List).map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 user list: $e');
    }
    return [];
  }

  /// Obtains a set of user attributes (C.6.14.2).
  Future<Map<String, dynamic>?> fetchUserAttributes(
    String userId, [
    String serviceContextId = 'current-service',
  ]) async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/$serviceContextId/users/$userId');
      final res = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 user attributes for $userId: $e');
    }
    return null;
  }

  /// Synchronizes TV 3.0 current user and profiles with GingaCC.
  Future<bool> syncWithGingaCC(
    GingaCC gingacc, [
    String serviceContextId = 'current-service',
  ]) async {
    final user = await fetchCurrentUser(serviceContextId);
    if (user != null && user.id.isNotEmpty) {
      gingacc.config.users.registerUser(user);
      gingacc.config.users.setCurrentUser(user.id);
      gingacc.config.systemVariables['currentUser'] = user.id;
      gingacc.config.systemVariables['user.id'] = user.id;
      gingacc.config.systemVariables['user.name'] = user.name;
      for (final entry in user.properties.entries) {
        gingacc.config.systemVariables['user.${entry.key}'] =
            entry.value.toString();
      }
      return true;
    }
    return false;
  }

  /// Reads TV 3.0 Manifest headers (C.3.4).
  Future<Map<String, String>?> fetchManifest() async {
    try {
      final uri = Uri.parse('$baseUrl/manifest');
      final res = await _client.get(uri);
      if (res.statusCode == 200) {
        return res.headers;
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 manifest: $e');
    }
    return null;
  }

  void close() {
    _client.close();
  }
}
