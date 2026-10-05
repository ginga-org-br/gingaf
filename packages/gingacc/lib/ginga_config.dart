import 'dart:convert';

import 'package:json5/json5.dart';

import 'gingacc.dart';

typedef Bounds = ({double left, double top, double width, double height});

/// Ginga environment configuration.
///
/// Example configuration JSON:
/// ```json
/// {
///   "appSrc": "main.ncl",
///   "mainAvSrc": "video.mp4",
///   "startWithCCWS": true,
///   "startWithMainAv": true,
///   "systemVariables": {
///     "system.language": "por",
///     "user.age": "30",
///     "default.font": "sans",
///     "service.id": "1",
///     "si.ts": "2",
///     "channel.num": "10",
///     "shared.key": "val"
///   },
///   "usersDataJson": [
///     {
///       "id": "u1",
///       "name": "User 1",
///       "properties": {
///         "age": 30,
///         "closedCaptioning": true
///       }
///     }
///   ]
/// }
/// ```
///
/// Note: `"usersDataJson"` can also be a URI or file path string pointing to a JSON file (e.g. `"usersDataJson": "users.json"`).

class GingaConfig {
  static const String defaultMainAvSrc =
      "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4";
  static const String defaultMainAVSrc = defaultMainAvSrc;

  static const List<String> supportedGroups = [
    'system.',
    'user.',
    'default.',
    'service.',
    'si.',
    'channel.',
    'shared.',
  ];

  String? appSrc;
  final String mainAvSrc;
  final bool startWithCCWS;
  final bool startWithMainAv;
  final Bounds graphicPlaneBounds;
  final Map<String, String> systemVariables;
  final Users users;

  GingaConfig({
    this.appSrc,
    this.startWithCCWS = false,
    this.startWithMainAv = false,
    this.mainAvSrc = defaultMainAvSrc,
    this.graphicPlaneBounds = const (
      left: 0.0,
      top: 0.0,
      width: 720.0,
      height: 480.0,
    ),
    Map<String, String>? systemVariables,
    Users? users,
  })  : systemVariables = {
          'system.language': 'por',
          ...?systemVariables,
        },
        users = users ?? Users();

  Map<String, String> getGroup(String group) {
    final prefix = group.endsWith('.') ? group : '$group.';
    final result = <String, String>{};
    for (final entry in systemVariables.entries) {
      if (entry.key.startsWith(prefix)) {
        result[entry.key.substring(prefix.length)] = entry.value;
      }
    }
    return result;
  }

  static Future<GingaConfig> fromJson(
    String jsonOrSrc, [
    String? baseDirSrc,
    GingaCC? gingacc,
  ]) async {
    gingacc ??= GingaCC();
    var trimmed = jsonOrSrc.trim();
    if (trimmed.isEmpty) {
      return GingaConfig();
    }
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      final unquoted = trimmed.substring(1, trimmed.length - 1).trim();
      if (unquoted.startsWith('{') || unquoted.startsWith('[')) {
        trimmed = unquoted;
      }
    }
    String jsonString;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      jsonString = trimmed;
    } else {
      final uri = gingacc.resolveUri(trimmed, baseDirSrc);
      final loaded = (await gingacc.loadContent(uri)) ??
          (await gingacc.loadContent(trimmed));
      if (loaded == null) {
        throw FormatException('Failed to load GingaConfig from $jsonOrSrc');
      }
      jsonString = loaded.trim();
    }
    final dynamic decoded;
    try {
      decoded = json5Decode(jsonString);
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException(e.toString());
    }
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object for GingaConfig');
    }

    final Map<String, String> envVars = {};

    void extractFromMap(Map map, [String prefix = '']) {
      for (final entry in map.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final fullKey = prefix.isEmpty ? key : '$prefix$key';
        if (value is Map) {
          extractFromMap(value, '$fullKey.');
        } else if (value != null) {
          envVars[fullKey] = value.toString();
        }
      }
    }

    final rawEnv = decoded['systemVariables'] ?? decoded['envVariables'];
    if (rawEnv is Map) {
      extractFromMap(rawEnv);
    }

    for (final group in supportedGroups) {
      final groupName = group.substring(0, group.length - 1);
      final val = decoded[groupName] ?? decoded[group];
      if (val is Map) {
        extractFromMap(val, group);
      }
    }

    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      for (final group in supportedGroups) {
        if (key.startsWith(group) &&
            entry.value != null &&
            entry.value is! Map) {
          envVars[key] = entry.value.toString();
        }
      }
    }

    final users = Users();
    final usersObj = decoded['usersDataJson'] ?? decoded['userDataJson'];
    if (usersObj is String) {
      final trimmedUsers = usersObj.trim();
      if (trimmedUsers.startsWith('{') || trimmedUsers.startsWith('[')) {
        users.loadUserData(trimmedUsers);
      } else {
        final base = baseDirSrc ?? (trimmed.startsWith('{') ? null : trimmed);
        final uri = gingacc.resolveUri(trimmedUsers, base);
        final loaded = (await gingacc.loadContent(uri)) ??
            (await gingacc.loadContent(trimmedUsers));
        if (loaded != null && loaded.isNotEmpty) {
          users.loadUserData(loaded);
        }
      }
    } else if (usersObj is List) {
      users.importUsers(usersObj);
    } else if (usersObj is Map<String, dynamic>) {
      users.loadUserData(jsonEncode(usersObj));
    } else if (usersObj is Map) {
      users.loadUserData(jsonEncode(Map<String, dynamic>.from(usersObj)));
    }

    const allowedKeys = {
      'appSrc',
      'mainAvSrc',
      'startWithCCWS',
      'startWithMainAv',
      'graphicPlaneBounds',
      'graphicPlaneWidth',
      'graphicPlaneHeight',
      'systemVariables',
      'envVariables',
      'usersDataJson',
      'userDataJson',
    };

    for (final key in decoded.keys) {
      final keyStr = key.toString();
      if (allowedKeys.contains(keyStr)) continue;
      final isGroup = supportedGroups.any((g) =>
          keyStr == g ||
          keyStr == g.substring(0, g.length - 1) ||
          keyStr.startsWith(g));
      if (!isGroup) {
        throw FormatException("Format error: bad key '$keyStr'");
      }
    }

    Bounds planeBounds =
        const (left: 0.0, top: 0.0, width: 720.0, height: 480.0);
    final rawBounds = decoded['graphicPlaneBounds'];
    if (rawBounds is Map) {
      planeBounds = (
        left: (rawBounds['left'] as num?)?.toDouble() ?? 0.0,
        top: (rawBounds['top'] as num?)?.toDouble() ?? 0.0,
        width: (rawBounds['width'] as num?)?.toDouble() ?? 720.0,
        height: (rawBounds['height'] as num?)?.toDouble() ?? 480.0,
      );
    } else if (rawBounds is List && rawBounds.length >= 4) {
      planeBounds = (
        left: (rawBounds[0] as num).toDouble(),
        top: (rawBounds[1] as num).toDouble(),
        width: (rawBounds[2] as num).toDouble(),
        height: (rawBounds[3] as num).toDouble(),
      );
    } else if (decoded.containsKey('graphicPlaneWidth') ||
        decoded.containsKey('graphicPlaneHeight')) {
      final rawW = decoded['graphicPlaneWidth'];
      final w = rawW is num
          ? rawW.toDouble()
          : (rawW != null ? double.tryParse(rawW.toString()) ?? 720.0 : 720.0);
      final rawH = decoded['graphicPlaneHeight'];
      final h = rawH is num
          ? rawH.toDouble()
          : (rawH != null ? double.tryParse(rawH.toString()) ?? 480.0 : 480.0);
      planeBounds = (left: 0.0, top: 0.0, width: w, height: h);
    }

    return GingaConfig(
      appSrc: decoded['appSrc'] as String?,
      mainAvSrc: decoded['mainAvSrc'] as String? ?? defaultMainAvSrc,
      startWithCCWS: decoded['startWithCCWS'] as bool? ?? false,
      startWithMainAv: decoded['startWithMainAv'] as bool? ?? false,
      graphicPlaneBounds: planeBounds,
      systemVariables: envVars,
      users: users,
    );
  }

  @override
  String toString() {
    final parts = <String>[
      'appSrc: $appSrc',
      if (mainAvSrc.isNotEmpty && mainAvSrc != defaultMainAvSrc)
        'mainAvSrc: $mainAvSrc',
      'startWithCCWS: $startWithCCWS',
      'startWithMainAv: $startWithMainAv',
      'systemVariables: $systemVariables',
      if (users.isNotEmpty) 'users: $users',
    ];
    return 'GingaConfig(${parts.join(', ')})';
  }
}
