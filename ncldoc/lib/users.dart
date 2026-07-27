
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
  final Map<String, NCLUserProfile> _profiles = {};
  String? _activeUserId;

  void registerProfile(NCLUserProfile profile) {
    _profiles[profile.id] = profile;
  }

  NCLUserProfile? getProfile(String id) {
    return _profiles[id];
  }

  bool evaluateProfile(String id) {
    final profile = _profiles[id];
    if (profile == null) return false;
    for (final user in allUsers) {
      if (profile.matches(user)) {
        return true;
      }
    }
    return false;
  }

  void registerUser(NCLUserData user) {
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

class NCLUserProfile {
  final String id;
  final String? src;
  final Map<String, dynamic> query;

  NCLUserProfile({
    required this.id,
    this.src,
    required this.query,
  });

  bool matches(NCLUserData user) {
    return _evaluate(query, user);
  }

  bool _evaluate(Map<String, dynamic> expr, NCLUserData user) {
    var andList = expr['and'] ?? expr['AND'];
    var orList = expr['or'] ?? expr['OR'];
    final op = expr['operator']?.toString().toLowerCase();
    if (op == 'and') andList ??= expr['rules'];
    if (op == 'or') orList ??= expr['rules'];

    if (andList != null) {
      if (andList is List) {
        for (var item in andList) {
          if (item is Map<String, dynamic>) {
            if (!_evaluate(item, user)) return false;
          }
        }
        return true;
      }
      return false;
    }

    if (orList != null) {
      if (orList is List) {
        for (var item in orList) {
          if (item is Map<String, dynamic>) {
            if (_evaluate(item, user)) return true;
          }
        }
        return false;
      }
      return false;
    }

    if (expr.containsKey('attribute')) {
      final attName = expr['attribute'] as String;
      final comp = expr['comparator'] as String;
      final value = expr['value']?.toString() ?? '';

      final userVal = user.getProperty(attName);
      if (userVal == null) return false;

      final uvStr = userVal.toString();

      switch (comp) {
        case 'eq':
          return uvStr == value;
        case 'ne':
          return uvStr != value;
        case 'gt':
          final n1 = double.tryParse(uvStr);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 > n2;
          return uvStr.compareTo(value) > 0;
        case 'gte':
          final n1 = double.tryParse(uvStr);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 >= n2;
          return uvStr.compareTo(value) >= 0;
        case 'lt':
          final n1 = double.tryParse(uvStr);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 < n2;
          return uvStr.compareTo(value) < 0;
        case 'lte':
          final n1 = double.tryParse(uvStr);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 <= n2;
          return uvStr.compareTo(value) <= 0;
      }
    }

    return false;
  }
}
