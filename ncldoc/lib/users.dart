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

  dynamic getProperty(String propertyName) {
    if (_properties.containsKey(propertyName)) {
      return _properties[propertyName];
    }
    if (propertyName == 'id') return id;
    if (propertyName == 'name') return name;
    return null;
  }

  void setProperty(String propertyName, dynamic value) {
    _properties[propertyName] = value;
  }

  bool hasProperty(String propertyName) {
    if (_properties.containsKey(propertyName)) return true;
    if (propertyName == 'id') return id.isNotEmpty;
    if (propertyName == 'name') return name.isNotEmpty;
    return false;
  }

  Map<String, dynamic> get properties => Map.unmodifiable(_properties);

  factory NCLUserData.fromJson(Map<String, dynamic> json) {
    final initialProps = Map<String, dynamic>.from(json);
    initialProps.remove('id');
    initialProps.remove('name');
    if (initialProps.containsKey('properties')) {
      final nestedProps = initialProps.remove('properties');
      if (nestedProps is Map) {
        initialProps.addAll(Map<String, dynamic>.from(nestedProps));
      }
    }
    return NCLUserData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      initialProperties: initialProps.isNotEmpty ? initialProps : null,
    );
  }
}

class NCLUsers {
  final Map<String, NCLUserData> _users = {};
  final Map<String, NCLUserProfile> _profiles = {};
  String? _activeUserId;

  void registerUsers(List<NCLUserData> usersList) {
    for (final user in usersList) {
      registerUser(user);
    }
  }

  List<NCLUserData> getUsersByProperty(String propertyName, dynamic value) {
    final valStr = value?.toString();
    return allUsers
        .where((u) => u.getProperty(propertyName)?.toString() == valStr)
        .toList();
  }

  int countMatchingUsers(String profileId) {
    return getMatchingUsersForProfile(profileId).length;
  }

  dynamic getActiveUserProperty(String propertyName) {
    return activeUser?.getProperty(propertyName);
  }

  void registerProfile(NCLUserProfile profile) {
    _profiles[profile.id] = profile;
  }

  NCLUserProfile? getProfile(String id) {
    return _profiles[id];
  }

  List<NCLUserProfile> get allProfiles => _profiles.values.toList();

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

  bool evaluateProfileForUser(String profileId, String userId) {
    final profile = _profiles[profileId];
    final user = _users[userId];
    if (profile == null || user == null) return false;
    return profile.matches(user);
  }

  List<NCLUserData> getMatchingUsersForProfile(String profileId) {
    final profile = _profiles[profileId];
    if (profile == null) return [];
    return allUsers.where((user) => profile.matches(user)).toList();
  }

  List<NCLUserProfile> findProfilesForUser(NCLUserData user) {
    return allProfiles.where((profile) => profile.matches(user)).toList();
  }

  void importProfiles(List<dynamic> jsonList) {
    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        registerProfile(NCLUserProfile.fromJson(item));
      } else if (item is Map) {
        registerProfile(
          NCLUserProfile.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
  }

  List<Map<String, dynamic>> exportProfiles() {
    return _profiles.values.map((profile) => profile.toJson()).toList();
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

  void clear() {
    _users.clear();
    _profiles.clear();
    _activeUserId = null;
  }

  void loadUserData(String usersDataJson) {
    if (usersDataJson.trim().isEmpty) return;

    final decoded = json.decode(usersDataJson.trim());
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('id')) {
        registerUser(NCLUserData.fromJson(decoded));
      } else {
        final defaultUser =
            activeUser ?? NCLUserData(id: 'defaultUser', name: 'Default User');
        for (var entry in decoded.entries) {
          defaultUser.setProperty(entry.key, entry.value);
        }
        registerUser(defaultUser);
      }
    } else if (decoded is List) {
      importUsers(decoded);
    }
  }
}

class NCLUserProfile {
  final String id;
  final String? src;
  final Map<String, dynamic> query;

  NCLUserProfile({required this.id, this.src, required this.query});

  factory NCLUserProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final src = json['src'] as String?;
    final Map<String, dynamic> queryMap;
    if (json.containsKey('query') && json['query'] is Map) {
      queryMap = Map<String, dynamic>.from(json['query'] as Map);
    } else {
      final rest = Map<String, dynamic>.from(json);
      rest.remove('id');
      rest.remove('src');
      queryMap = rest;
    }
    return NCLUserProfile(id: id, src: src, query: queryMap);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, if (src != null) 'src': src, 'query': query};
  }

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
      final rawValue = expr['value'];
      final value = rawValue?.toString() ?? '';

      final userVal = user.getProperty(attName);
      if (userVal == null) return false;

      final uvStr = userVal.toString();

      switch (comp) {
        case 'eq':
          return uvStr == value;
        case 'neq':
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
        default:
          return false;
      }
    }

    return false;
  }
}
