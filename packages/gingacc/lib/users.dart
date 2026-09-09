import 'dart:convert';

class UserData {
  final String id;
  final String name;
  final Map<String, dynamic> _properties = {};

  UserData({
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

  factory UserData.fromJson(Map<String, dynamic> json) {
    final initialProps = Map<String, dynamic>.from(json);
    initialProps.remove('id');
    initialProps.remove('name');
    if (initialProps.containsKey('properties')) {
      final nestedProps = initialProps.remove('properties');
      if (nestedProps is Map) {
        initialProps.addAll(Map<String, dynamic>.from(nestedProps));
      }
    }
    return UserData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      initialProperties: initialProps.isNotEmpty ? initialProps : null,
    );
  }

  @override
  String toString() {
    return 'UserData(id: $id, name: $name, properties: $_properties)';
  }
}

class Users {
  final Map<String, UserData> _users = {};
  String? _activeUserId;

  Users([String? initialData]) {
    if (initialData != null) {
      loadUserData(initialData);
    }
  }

  void registerUsers(List<UserData> usersList) {
    for (final user in usersList) {
      registerUser(user);
    }
  }

  List<UserData> getUsersByProperty(String propertyName, dynamic value) {
    final valStr = value?.toString();
    return allUsers
        .where((u) => u.getProperty(propertyName)?.toString() == valStr)
        .toList();
  }

  int countMatchingUsers(UserProfileQuery profile) {
    return getMatchingUsersForProfile(profile).length;
  }

  dynamic getActiveUserProperty(String propertyName) {
    return activeUser?.getProperty(propertyName);
  }

  bool evaluateProfile(UserProfileQuery profile) {
    for (final user in allUsers) {
      if (profile.matches(user)) {
        return true;
      }
    }
    return false;
  }

  bool evaluateProfileForUser(UserProfileQuery profile, String userId) {
    final user = _users[userId];
    if (user == null) return false;
    return profile.matches(user);
  }

  List<UserData> getMatchingUsersForProfile(UserProfileQuery profile) {
    return allUsers.where((user) => profile.matches(user)).toList();
  }

  void registerUser(UserData user) {
    _users[user.id] = user;
    _activeUserId ??= user.id;
  }

  void removeUser(String id) {
    _users.remove(id);
    if (_activeUserId == id) {
      _activeUserId = _users.keys.firstOrNull;
    }
  }

  UserData? getUser(String id) {
    return _users[id];
  }

  UserData? get activeUser {
    if (_activeUserId == null) return null;
    return _users[_activeUserId];
  }

  void setActiveUser(String id) {
    if (_users.containsKey(id)) {
      _activeUserId = id;
    }
  }

  List<UserData> get allUsers => _users.values.toList();

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
        registerUser(UserData.fromJson(item));
      } else if (item is Map) {
        registerUser(UserData.fromJson(Map<String, dynamic>.from(item)));
      }
    }
  }

  void clear() {
    _users.clear();
    _activeUserId = null;
  }

  void loadUserData(String usersDataJson) {
    final sanitized = usersDataJson
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n')
        .trim();
    if (sanitized.isEmpty) return;

    final decoded = json.decode(sanitized);
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('id')) {
        registerUser(UserData.fromJson(decoded));
      } else {
        final defaultUser =
            activeUser ?? UserData(id: 'defaultUser', name: 'Default User');
        for (var entry in decoded.entries) {
          defaultUser.setProperty(entry.key, entry.value);
        }
        registerUser(defaultUser);
      }
    } else if (decoded is List) {
      importUsers(decoded);
    }
  }

  @override
  String toString() {
    return 'Users(activeUserId: $_activeUserId, users: ${_users.values.toList()})';
  }
}

class UserProfileQuery {
  final Map<String, dynamic> query;

  UserProfileQuery(this.query);

  factory UserProfileQuery.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('query') && json['query'] is Map) {
      return UserProfileQuery(Map<String, dynamic>.from(json['query'] as Map));
    }
    final rest = Map<String, dynamic>.from(json);
    rest.remove('id');
    rest.remove('src');
    return UserProfileQuery(rest);
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(query);
  }

  bool matches(UserData user) {
    return _evaluate(query, user);
  }

  bool _evaluate(Map<String, dynamic> expr, UserData user) {
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
