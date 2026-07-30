library;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'elements.dart';
import 'event.dart';
import 'file_content.dart';
import 'ncl_scheduler.dart';
import 'parser.dart';
import 'users.dart';

export 'elements.dart';
export 'event.dart';
export 'file_content.dart';
export 'lua.dart';
export 'ncl_scheduler.dart';
export 'parser.dart';
export 'users.dart';

final _logger = Logger('ncl_doc');

class NCLDocument {
  late final Head? _head;
  late final Context _body;
  late final Settings _settings;
  Uri? docUri;
  final String docSrc;
  final ContentLoader contentLoader;

  late final NCLScheduler scheduler = NCLScheduler(this);
  final NCLUsers users = NCLUsers();
  final Map<String, String> systemVariables = {'system.language': 'por'};

  static Future<NCLDocument> fromSrc(
    String docSrc, {
    String? userDataSrc,
    ContentLoader contentLoader = const FileContentLoader(),
  }) async {
    final xml = await contentLoader.load(docSrc);
    final userData = userDataSrc != null
        ? await contentLoader.load(userDataSrc, docSrc)
        : null;
    final doc = NCLDocument.fromContent(
      xml ?? '',
      docSrc: docSrc,
      userData: userData,
      contentLoader: contentLoader,
    );
    await doc.loadUserProfiles();
    return doc;
  }

  factory NCLDocument.fromContent(
    String xml, {
    String? docSrc,
    String? userData,
    ContentLoader contentLoader = const FileContentLoader(),
  }) {
    if (xml.trim().isEmpty) {
      throw ArgumentError('empty src');
    }
    final resolvedDocSrc = docSrc ?? 'tmp.ncl';
    final Uri? resolvedUri = docSrc != null ? Uri.tryParse(docSrc) : null;
    final (head, body) = NCLParser(
      docUri: resolvedUri,
      contentLoader: contentLoader,
    ).parseString(xml);
    return NCLDocument._(
      head: head,
      body: body,
      docSrc: resolvedDocSrc,
      docUri: resolvedUri,
      userData: userData,
      contentLoader: contentLoader,
    );
  }

  NCLDocument._({
    Head? head,
    required Body body,
    required this.docSrc,
    this.docUri,
    String? userData,
    ContentLoader contentLoader = const FileContentLoader(),
  }) : contentLoader = contentLoader {
    _head = head;
    _body = body;
    _gatherSettings();
    _gatherUsers(userData);
  }

  void _gatherUsers([String? userData]) {
    loadUserProfiles();
    if (userData != null) {
      users.loadUserData(userData);
    }
  }

  Future<void> loadUserProfiles() async {
    if (_head != null) {
      for (var el in headChildren) {
        if (el.xmlTagName == 'userBase') {
          for (var child in el.children) {
            if (child.xmlTagName == 'userProfile') {
              final id = child.rawAttributes['id'];
              final src = child.rawAttributes['src'];
              if (id != null && id.isNotEmpty) {
                await _loadUserProfile(id, src);
              }
            }
          }
        }
      }
    }
  }

  Future<void> _loadUserProfile(String id, String? src) async {
    if (src == null) return;
    try {
      final jsonContent = await contentLoader.load(src, docSrc);
      if (jsonContent != null && jsonContent.isNotEmpty) {
        final query = json.decode(jsonContent);
        users.registerProfile(NCLUserProfile(id: id, src: src, query: query));
      }
    } catch (_) {}
  }

  void _gatherSettings() {
    final settingsList = _body.children.whereType<Settings>();
    if (settingsList.isNotEmpty) {
      _settings = settingsList.first;
    } else {
      _settings = Settings(rawAttributes: const {'id': '__settings__'});
      _body.children.add(_settings);
      _settings.parent = _body;
    }
  }

  Head? get head => _head;
  Context get body => _body;
  NCLState getBodyState() => _body.getMainState();

  Settings getSettings() => _settings;

  void doNclEditingCommand(String command) {
    NCLParser(docUri: docUri, contentLoader: contentLoader).doNclEditingCommand(this, command);
  }

  Node? getNodeById(String id) {
    if (_body.id == id) return _body;

    Node? search(Composition comp) {
      for (var node in comp.getNodes()) {
        if (node.id == id) return node;
        if (node is Composition) {
          final res = search(node);
          if (res != null) return res;
        }
      }
      return null;
    }

    return search(_body);
  }

  Element? getElementById(String id) {
    Element? search(Element element) {
      if (element.id == id) return element;
      for (var child in element.children) {
        final res = search(child);
        if (res != null) return res;
      }
      return null;
    }

    for (var el in headChildren) {
      final res = search(el);
      if (res != null) return res;
    }
    return search(_body);
  }

  List<Element> get headChildren => _head ?? const [];

  bool evaluateRule(String ruleId) {
    final ruleBases = headChildren.where((el) => el.xmlTagName == 'ruleBase');
    if (ruleBases.isEmpty) return false;

    Element? findRule(Element parent, String id) {
      if ((parent.xmlTagName == 'rule' ||
              parent.xmlTagName == 'compositeRule') &&
          parent.rawAttributes['id'] == id) {
        return parent;
      }
      for (var child in parent.children) {
        final res = findRule(child, id);
        if (res != null) return res;
      }
      return null;
    }

    Element? ruleEl;
    for (final rb in ruleBases) {
      ruleEl = findRule(rb, ruleId);
      if (ruleEl != null) break;
    }
    if (ruleEl == null) return false;

    return _evaluateRuleElement(ruleEl);
  }

  bool _evaluateRuleElement(Element ruleEl) {
    if (ruleEl.xmlTagName == 'rule') {
      if (ruleEl.rawAttributes['var'] == null &&
          ruleEl.rawAttributes['id'] != null) {
        final refId = ruleEl.rawAttributes['id']!;
        if (refId != ruleEl.parent?.rawAttributes['id']) {
          final targetRule = getElementById(refId);
          if (targetRule != null && targetRule != ruleEl) {
            return _evaluateRuleElement(targetRule);
          }
        }
      }

      final varName = ruleEl.rawAttributes['var'] ?? '';
      final value = ruleEl.rawAttributes['value'] ?? '';
      final comparator = ruleEl.rawAttributes['comparator'] ?? 'eq';
      // NOT COMPLIANT: <rule> with user
      final userAttr = ruleEl.rawAttributes['user'];
      // NOT COMPLIANT ends
      var systemVal = systemVariables[varName];
      if (systemVal == null) {
        for (final s in _body.children.whereType<Settings>()) {
          var propName = varName;
          if (s.id != null && varName.startsWith('${s.id}.')) {
            propName = varName.substring(s.id!.length + 1);
          }
          // NOT COMPLIANT: <rule> with user
          if (userAttr != null && userAttr.isNotEmpty) {
            final profileId = s.rawAttributes['user'];
            if (profileId != null &&
                profileId != userAttr &&
                profileId != 'currentUser' &&
                userAttr != 'currentUser') {
              continue;
            }
          }
          // NOT COMPLIANT ends
          final val = getPropertyValue(s, propName);
          if (val != null) {
            systemVal = val;
            break;
          }
        }
      }
      // NOT COMPLIANT: <rule> with user
      if (systemVal == null && userAttr != null && userAttr.isNotEmpty) {
        final activeUser = users.activeUser;
        if (activeUser != null) {
          final userVal = activeUser.getProperty(varName);
          if (userVal != null) {
            systemVal = userVal.toString();
          }
        }
      }
      // NOT COMPLIANT ends
      systemVal ??= '';

      switch (comparator) {
        case 'eq':
          return systemVal == value;
        case 'ne':
          return systemVal != value;
        case 'gt':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 > n2;
          return systemVal.compareTo(value) > 0;
        case 'lt':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 < n2;
          return systemVal.compareTo(value) < 0;
        case 'gte':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 >= n2;
          return systemVal.compareTo(value) >= 0;
        case 'lte':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 <= n2;
          return systemVal.compareTo(value) <= 0;
      }
      return false;
    } else if (ruleEl.xmlTagName == 'compositeRule') {
      final operator = ruleEl.rawAttributes['operator'] ?? 'and';
      final results = ruleEl.children
          .where(
            (c) => c.xmlTagName == 'rule' || c.xmlTagName == 'compositeRule',
          )
          .map((c) => _evaluateRuleElement(c));
      if (results.isEmpty) return false;
      if (operator == 'and') {
        return results.every((r) => r);
      } else {
        return results.any((r) => r);
      }
    }
    return false;
  }

  Node? resolveSwitch(Switch switchNode) {
    final bindRules = switchNode.children.where(
      (c) => c.xmlTagName == 'bindRule',
    );
    for (var bindRule in bindRules) {
      final ruleId = bindRule.rawAttributes['rule'];
      final constituentId = bindRule.rawAttributes['constituent'];
      if (ruleId != null && constituentId != null) {
        if (evaluateRule(ruleId)) {
          final res = getNodeById(constituentId);
          if (res != null) return res;
        }
      }
    }
    final defaultComp = switchNode.children
        .where((c) => c.xmlTagName == 'defaultComponent')
        .firstOrNull;
    if (defaultComp != null) {
      final compId = defaultComp.rawAttributes['component'];
      if (compId != null) {
        return getNodeById(compId);
      }
    }
    return null;
  }

  List<Media> getActiveMedia() {
    final active = <Media>[];
    void search(Composition comp) {
      for (var node in comp.getNodes()) {
        if (node is Media && node.getMainState() == NCLState.OCCURRING) {
          active.add(node);
        } else if (node is Composition) {
          search(node);
        }
      }
    }

    search(_body);
    return active;
  }

  Element? getConnectorById(String id) {
    final connBase = headChildren
        .where((el) => el.xmlTagName == 'connectorBase')
        .firstOrNull;
    if (connBase != null) {
      for (var child in connBase.children) {
        if (child.rawAttributes['id'] == id) {
          return child;
        }
      }
    }
    return null;
  }

  bool _hasUserSettingsMedia(Element root) {
    if (root.rawAttributes['type'] == 'application/x-ncl-user-settings' &&
        root.rawAttributes['user'] == 'currentUser') {
      return true;
    }
    for (var child in root.children) {
      if (_hasUserSettingsMedia(child)) return true;
    }
    return false;
  }

  String? getPropertyValue(Node node, String propertyName) {
    if (node is Settings) {
      final isUserSetting =
          node.mimeType == 'application/x-ncl-user-settings' ||
          node.rawAttributes['type'] == 'application/x-ncl-user-settings';

      bool hasCurrentUser = node.rawAttributes['user'] == 'currentUser';
      if (!hasCurrentUser && node == _settings) {
        hasCurrentUser = _hasUserSettingsMedia(_body);
      }

      if (isUserSetting || hasCurrentUser) {
        // NOT COMPLIANT: <rule> with user
        final hasPropertyDecl = node.children.whereType<Property>().any(
          (p) => p.name == propertyName,
        );
        // NOT COMPLIANT ends
        if (hasPropertyDecl) {
          final user = users.activeUser;
          if (user != null) {
            final userVal = user.getProperty(propertyName);
            if (userVal != null) {
              return userVal.toString();
            }
          }
        }
      }
    }

    var currentNode = node;
    final referId = currentNode.rawAttributes['refer'];
    if (referId != null) {
      final refNode = getNodeById(referId);
      if (refNode != null) {
        currentNode = refNode;
      }
    }
    final prop = currentNode.children
        .whereType<Property>()
        .where((p) => p.name == propertyName)
        .firstOrNull;
    return prop?.value;
  }

  int get virtualClock => scheduler.virtualClock;
  set virtualClock(int val) => scheduler.virtualClock = val;
  bool get isPlaying => scheduler.isPlaying;
  set isPlaying(bool val) => scheduler.isPlaying = val;
  List<Action> get uiQueue => scheduler.uiQueue;

  void start() => scheduler.start();
  void stop() => scheduler.stop();
  Set<Media> tick([int incrementMs = 0]) => scheduler.tick(incrementMs);
  void tickIndefinitely({int ticksPerSecond = 10, void Function()? onStop}) =>
      scheduler.tickIndefinitely(
        ticksPerSecond: ticksPerSecond,
        onStop: onStop,
      );
  void triggerSelection(String componentId, String keyCode) =>
      scheduler.triggerSelection(componentId, keyCode);
}
