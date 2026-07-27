
import 'dart:convert';

class NCLUserData {
  final String id;
  final String name;
  final Map<String, dynamic> _properties = {};

  NCLUserData({
    required this.id,
    required this.name,
    Map<String, dynamic>? initialProperties,
  }) {
    if (initialProperties != null) {
      _properties.addAll(initialProperties);
    }
  }

  dynamic getProperty(String name) {
    return _properties[name];
  }

  void setProperty(String name, dynamic value) {
    _properties[name] = value;
  }

  bool hasProperty(String name) {
    return _properties.containsKey(name);
  }

  Map<String, dynamic> get properties => Map.unmodifiable(_properties);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'properties': Map<String, dynamic>.from(_properties),
    };
  }

  factory NCLUserData.fromJson(Map<String, dynamic> json) {
    return NCLUserData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      initialProperties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'] as Map)
          : null,
    );
  }
}

class NCLUsers {
  final Map<String, NCLUserData> _users = {};
  String? _activeUserId;

  void registerUser(NCLUser user) {
    _users[user.id] = user;
    _activeUserId ??= user.id;
  }

  void removeUser(String id) {
    _users.remove(id);
    if (_activeUserId == id) {
      _activeUserId = _users.keys.firstOrNull;
    }
  }

  NCLUserData? getUser(String id) {
    return _users[id];
  }

  NCLUserData? get activeUser {
    if (_activeUserId == null) return null;
    return _users[_activeUserId];
  }

  void setActiveUser(String id) {
    if (_users.containsKey(id)) {
      _activeUserId = id;
    }
  }

  List<NCLUserData> get allUsers => _users.values.toList();

  dynamic getUserProperty(String userId, String propertyName) {
    final user = _users[userId];
    if (user == null) return null;
    return user.getProperty(propertyName);
  }

  bool setUserProperty(String userId, String propertyName, dynamic value) {
    final user = _users[userId];
    if (user != null) {
      user.setProperty(propertyName, value);
      return true;
    }
    return false;
  }


  void importUsers(List<dynamic> jsonList) {
    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        registerUser(NCLUserData.fromJson(item));
      } else if (item is Map) {
        registerUser(NCLUserData.fromJson(Map<String, dynamic>.from(item)));
      }
    }
  }

  final Map<String, Set<String>> _usersSessions = {};

  bool createUsersSession(String sessionId) {
    if (_usersSessions.containsKey(sessionId)) return false;
    _usersSessions[sessionId] = {};
    return true;
  }

  bool joinUsersSession(String sessionId, String userId) {
    if (!_users.containsKey(userId)) return false;
    _usersSessions.putIfAbsent(sessionId, () => {});
    _usersSessions[sessionId]!.add(userId);
    return true;
  }

  bool leaveUsersSession(String sessionId, String userId) {
    final session = _usersSessions[sessionId];
    if (session == null) return false;
    return session.remove(userId);
  }

  List<NCLUserData> getUsersSessionUsers(String sessionId) {
    final userIds = _usersSessions[sessionId];
    if (userIds == null) return [];
    return userIds.map((id) => _users[id]).whereType<NCLUserData>().toList();
  }

  List<String> getUsersSessionIds() {
    return _usersSessions.keys.toList();
  }

  bool removeUsersSession(String sessionId) {
    return _usersSessions.remove(sessionId) != null;
  }

  Map<String, dynamic> getSessionPropertyValues(String sessionId, String propertyName) {
    final sessionUsers = getUsersSessionUsers(sessionId);
    final Map<String, dynamic> result = {};
    for (final user in sessionUsers) {
      if (user.hasProperty(propertyName)) {
        result[user.id] = user.getProperty(propertyName);
      }
    }
    return result;
  }

  void clear() {
    _users.clear();
    _usersSessions.clear();
    _activeUserId = null;
  }

  void loadUserData(String usersDataJson, {String? Function(Uri uri)? resolver}) {
    if (usersDataJson.trim().isEmpty) return;

    try {
      final content = usersDataJson.trim();
      if (content.startsWith('{') || content.startsWith('[')) {
        _parseAndImportUserDataJson(content);
      } else {
        final uri = Uri.tryParse(content);
        if (uri != null && resolver != null) {
          final fileContent = resolver(uri);
          if (fileContent != null) {
            _parseAndImportUserDataJson(fileContent);
          }
        }
      }
    } catch (_) {}
  }

  void _parseAndImportUserDataJson(String jsonStr) {
    final decoded = json.decode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('id')) {
        registerUser(NCLUserData.fromJson(decoded));
      } else {
        final defaultUser =
            activeUser ??
            NCLUserData(id: 'defaultUser', name: 'Default User');
        for (var entry in decoded.entries) {
          defaultUser.setProperty(entry.key, entry.value);
        }
        registerUser(defaultUser);
      }
    } else if (decoded is List) {
      for (var item in decoded) {
        if (item is Map<String, dynamic>) {
          registerUser(NCLUserData.fromJson(item));
        }
      }
    }
  }
}

