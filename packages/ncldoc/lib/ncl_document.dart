library;

import 'dart:async';
import 'dart:convert';

import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';

import 'elements.dart';
import 'event.dart';
import 'ncl_scheduler.dart';
import 'ncl_strings.dart';
import 'parser.dart';

export 'package:gingacc/gingacc.dart';

export 'elements.dart';
export 'event.dart';
export 'lua_runtime.dart';
export 'ncl_scheduler.dart';
export 'parser.dart';

final _logger = Logger('ncl_doc');

class NclDocument {
  late final Head? _head;
  late final Context _body;
  Uri? docUri;
  final String docSrc;

  late final NclScheduler scheduler = NclScheduler(this);
  Users get users => gingacc.config.users;
  GingaConfig get config => gingacc.config;
  final Map<String, UserProfileQuery> _loadedProfiles = {};
  Map<String, UserProfileQuery> get loadedProfiles => _loadedProfiles;
  late final Map<String, String> _systemVariables;

  String? getSystemVariable(String name) => _systemVariables[name];
  String? getSystemVarible(String name) => getSystemVariable(name);

  void setSystemVariable(
    String name,
    String value, {
    Node? originNode,
  }) {
    _systemVariables[name] = value;
    if (name == 'service.currentFocus') {
      if (_currentFocusNodeId != value) {
        setFocus(value);
      }
    } else if (name == 'service.currentKeyMaster') {
      if (currentKeyMaster != value) {
        setKeyMaster(value);
      }
    }
    for (final s in body.descendants.whereType<Settings>()) {
      if (s != originNode &&
          s.children.whereType<Property>().any((p) => p.name == name)) {
        if (originNode != null && getPropertyValue(s, name) == value) {
          continue;
        }
        s.setPropertyValue(name, value);
        scheduler.stackNclAction(
          s.getPropertyNclEvent(name),
          NclActionType.set,
          value: value,
        );
      }
    }
    onStateChanged?.call();
  }

  final GingaCC gingacc;
  void Function()? onStateChanged;

  static Future<NclDocument> fromSrc(
    String docSrc, {
    GingaCC? gingacc,
  }) async {
    _logger.info('Loading NCL document from src: $docSrc');
    gingacc ??= GingaCC();
    final String? xml;
    if (isXmlString(docSrc)) {
      xml = docSrc;
    } else {
      final docUri = gingacc.resolveUri(docSrc);
      xml = await gingacc.loadContent(docUri);
    }

    final doc = NclDocument.fromContent(
      xml ?? '',
      docSrc: docSrc,
      gingacc: gingacc,
    );
    return doc;
  }

  factory NclDocument.fromContent(
    String xml, {
    String? docSrc,
    GingaCC? gingacc,
  }) {
    if (xml.trim().isEmpty) {
      throw ArgumentError('empty src');
    }
    final resolvedDocSrc = docSrc ?? 'tmp.ncl';
    _logger.fine('Creating NclDocument from content (src: $resolvedDocSrc)');
    final cc = gingacc ?? GingaCC();
    final Uri? resolvedUri =
        (docSrc != null && !isXmlString(docSrc)) ? cc.resolveUri(docSrc) : null;
    final doc = NclDocument._(
      docSrc: resolvedDocSrc,
      docUri: resolvedUri,
      gingacc: cc,
    );
    final (head, body) = NclParser(
      docUri: resolvedUri,
      document: doc,
    ).parseString(xml);
    doc._init(head: head, body: body);
    return doc;
  }

  NclDocument._({
    required this.docSrc,
    this.docUri,
    GingaCC? gingacc,
  })  : gingacc = gingacc ?? GingaCC(),
        _systemVariables = {
          ...(gingacc ?? GingaCC()).config.systemVariables,
        };

  void _init({Head? head, required Body body}) {
    _head = head;
    _body = body;
    for (final s in body.descendants.whereType<Settings>()) {
      for (final p in s.children.whereType<Property>()) {
        if (p.name != null && p.value != null) {
          _systemVariables.putIfAbsent(p.name!, () => p.value!);
        }
      }
    }
    _loadUserProfiles();
  }

  Future<void> _loadUserProfiles() async {
    if (_head != null) {
      for (var el in headChildren) {
        if (el.xmlTagName == 'userBase') {
          for (var child in el.children) {
            if (child.xmlTagName == 'userProfile') {
              final id = child.rawAttributes['id'];
              final src = child.rawAttributes['src'];
              if (id != null && id.isNotEmpty && src != null && src.isNotEmpty) {
                await _loadUserProfile(id, src);
              }
            }
          }
        }
      }
    }
  }

  UserProfile? getUserProfileById(String id) {
    if (_head != null) {
      for (var el in headChildren) {
        if (el.xmlTagName == 'userBase') {
          for (var child in el.children) {
            if (child.xmlTagName == 'userProfile' &&
                child.id == id &&
                child is UserProfile) {
              return child;
            }
          }
        }
      }
    }
    final node = getElementById(id);
    return node is UserProfile ? node : null;
  }

  bool _isUserProfile(String id) {
    if (_head != null) {
      for (var el in headChildren) {
        if (el.xmlTagName == 'userBase') {
          for (var child in el.children) {
            if (child.xmlTagName == 'userProfile' &&
                child.rawAttributes['id'] == id) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  Future<void> _loadUserProfile(String id, String? src) async {
    if (src == null) return;
    try {
      _logger.fine('Loading user profile "$id" from src: $src');
      final profileUri = gingacc.resolveUri(src, docSrc);
      final jsonContent = await gingacc.loadContent(profileUri);
      if (jsonContent != null && jsonContent.isNotEmpty) {
        final query = json.decode(jsonContent);
        final queryMap = query is Map<String, dynamic>
            ? query
            : (query is Map
                ? Map<String, dynamic>.from(query)
                : <String, dynamic>{});
        _loadedProfiles[id] = UserProfileQuery.fromJson(queryMap);
      }
    } catch (_) {}
  }



  Head? get head => _head;
  Context get body => _body;
  NclStateType getBodyState() => _body.getMainState();

  void doNclEditingCommand(String command) {
    NclParser(docUri: docUri, document: this)
        .doNclEditingCommand(this, command);
  }

  Node? getNodeById(String id) {
    if (_body.id == id) return _body;
    return _body.descendants
        .whereType<Node>()
        .where((n) => n.id == id)
        .firstOrNull;
  }

  Context? getContextById(String id) {
    if (_body.id == id) return _body;
    return _body.descendants
        .whereType<Context>()
        .where((c) => c.id == id)
        .firstOrNull;
  }

  Switch? getSwitchById(String id) {
    return _body.descendants
        .whereType<Switch>()
        .where((s) => s.id == id)
        .firstOrNull;
  }

  Media? getMediaById(String id) {
    return _body.descendants
        .whereType<Media>()
        .where((m) => m.id == id)
        .firstOrNull;
  }

  Element? getElementById(String id) {
    if (_body.id == id) return _body;
    final inHead = headChildren
        .expand((el) => [el, ...el.descendants])
        .where((el) => el.id == id)
        .firstOrNull;
    if (inHead != null) return inHead;
    return _body.descendants.where((el) => el.id == id).firstOrNull;
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
      var systemVal = _systemVariables[varName];

      // NOT COMPLIANT: <rule> with user
      final userAttr = ruleEl.rawAttributes['user'];
      if (systemVal == null && userAttr != null && userAttr.isNotEmpty) {
        for (final s in body.children.whereType<UserSettings>()) {
          final profileId = s.user;
          if (profileId != userAttr &&
              profileId != 'currentUser' &&
              userAttr != 'currentUser') {
            continue;
          }
          var propName = varName;
          if (s.id != null && varName.startsWith('${s.id}.')) {
            propName = varName.substring(s.id!.length + 1);
          }
          final val = getPropertyValue(s, propName);
          if (val != null) {
            systemVal = val;
            break;
          }
        }
        if (systemVal == null) {
          final currentUser = users.currentUser;
          if (currentUser != null) {
            final userVal = currentUser.getProperty(varName);
            if (userVal != null) {
              systemVal = userVal.toString();
            }
          }
        }
      }
      // NOT COMPLIANT ends

      if (varName == 'service.currentFocus') {
        final currentFocus = systemVal ??
            _systemVariables['service.currentFocus'] ??
            _currentFocusNodeId ??
            '';
        bool isFocusMatch(String expected) {
          if (currentFocus == expected) return true;
          final focusedNode = getNodeById(currentFocus);
          if (focusedNode is Media) {
            final fIndex = getFocusIndexForMedia(focusedNode);
            if (fIndex != null && fIndex == expected) return true;
          }
          final targetNode = getNodeById(expected);
          if (targetNode is Media) {
            final fIndex = getFocusIndexForMedia(targetNode);
            if (fIndex != null && fIndex == currentFocus) return true;
          }
          return false;
        }

        if (comparator == 'eq') {
          return isFocusMatch(value);
        } else if (comparator == 'ne') {
          return !isFocusMatch(value);
        }
      }

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

  List<Media> getActiveMedia() => _body.descendants
      .whereType<Media>()
      .where((m) => m.getMainState() == NclStateType.occurring)
      .toList();

  Element? getConnectorById(String id) => headChildren
      .where((el) => el.xmlTagName == 'connectorBase')
      .firstOrNull
      ?.children
      .where((c) => c.rawAttributes['id'] == id)
      .firstOrNull;

  String? getPropertyValue(Node? node, String propertyName) {
    if (node == null || node is Settings) {
      return _systemVariables[propertyName];
    }

    if (node is UserSettings) {
      final hasPropertyDecl = node.children.whereType<Property>().any(
            (p) => p.name == propertyName,
          );
      if (hasPropertyDecl) {
        final userAttr = node.user;
        final UserData? targetUser;
        if (userAttr != 'currentUser') {
          if (_isUserProfile(userAttr)) {
            final profile = _loadedProfiles[userAttr];
            targetUser = profile != null
                ? users.getMatchingUsersForProfile(profile).firstOrNull
                : (users.getUser(userAttr) ?? users.currentUser);
          } else {
            targetUser = users.getUser(userAttr);
          }
        } else {
          targetUser = users.currentUser;
        }
        final userVal = targetUser?.getProperty(propertyName);
        if (userVal != null) {
          return userVal.toString();
        }
        return _systemVariables['user.$propertyName'] ??
            _systemVariables[propertyName];
      }
      return null;
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
  List<NclAction> get uiQueue => scheduler.uiQueue;

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

  String? _currentFocusNodeId;
  String? get currentFocusNodeId => _currentFocusNodeId;

  Descriptor? getDescriptorForMedia(Media media) {
    var descId = media.descriptorId;
    if (descId == null && media.rawAttributes['refer'] != null) {
      final referNode = getNodeById(media.rawAttributes['refer']!);
      if (referNode is Media) {
        descId = referNode.descriptorId;
      }
    }
    if (descId == null) return null;
    final descEl = getElementById(descId);
    return descEl is Descriptor ? descEl : null;
  }

  String? getFocusIndexForMedia(Media media) {
    return getDescriptorForMedia(media)?.focusIndex;
  }

  Media? getActiveMediaByFocusIndex(String focusIndex) {
    for (var m in getActiveMedia()) {
      if (getFocusIndexForMedia(m) == focusIndex || m.id == focusIndex) {
        return m;
      }
    }
    return null;
  }

  void setFocus(String mediaId) {
    if (mediaId.isEmpty) return;
    var actualId = mediaId;
    final mediaByIndex = getActiveMediaByFocusIndex(mediaId);
    if (mediaByIndex != null && mediaByIndex.id != null) {
      actualId = mediaByIndex.id!;
    }
    _currentFocusNodeId = actualId;
    setSystemVariable('service.currentFocus', actualId);
  }

  String? get currentKeyMaster {
    final env = _systemVariables['service.currentKeyMaster'];
    if (env != null && env.isNotEmpty) return env;
    return null;
  }

  void setKeyMaster(String? mediaId) {
    if (mediaId == null || mediaId.isEmpty) {
      _systemVariables.remove('service.currentKeyMaster');
    } else {
      _systemVariables['service.currentKeyMaster'] = mediaId;
    }
    onStateChanged?.call();
  }

  void moveFocus(String direction) {
    final active = getActiveMedia();
    if (active.isEmpty) return;

    Media? currentMedia;
    if (_currentFocusNodeId != null) {
      currentMedia =
          active.where((m) => m.id == _currentFocusNodeId).firstOrNull;
    }
    if (currentMedia == null) {
      final focusable =
          active.where((m) => getFocusIndexForMedia(m) != null).toList();
      if (focusable.isNotEmpty) {
        focusable.sort((a, b) {
          final fa = int.tryParse(getFocusIndexForMedia(a) ?? '') ?? 999;
          final fb = int.tryParse(getFocusIndexForMedia(b) ?? '') ?? 999;
          return fa.compareTo(fb);
        });
        setFocus(focusable.first.id!);
      }
      return;
    }

    final currentDesc = getDescriptorForMedia(currentMedia);
    if (currentDesc == null) return;

    String? targetFocusIndex;
    final dir = NclKeys.normalizeKey(direction);
    switch (dir) {
      case NclKeys.cursorRight:
        targetFocusIndex = currentDesc.moveRight;
        break;
      case NclKeys.cursorLeft:
        targetFocusIndex = currentDesc.moveLeft;
        break;
      case NclKeys.cursorUp:
        targetFocusIndex = currentDesc.moveUp;
        break;
      case NclKeys.cursorDown:
        targetFocusIndex = currentDesc.moveDown;
        break;
    }

    if (targetFocusIndex != null) {
      final targetMedia = getActiveMediaByFocusIndex(targetFocusIndex);
      if (targetMedia != null && targetMedia.id != null) {
        setFocus(targetMedia.id!);
      }
    }
  }

  void handleSelection([String? componentId, String keyCode = 'ENTER']) {
    var targetId = componentId ?? _currentFocusNodeId;
    if (targetId == null) {
      moveFocus('NONE');
      targetId = _currentFocusNodeId;
    }
    if (targetId != null && targetId.isNotEmpty) {
      setFocus(targetId);
      scheduler.triggerSelection(targetId, keyCode);
      onStateChanged?.call();
    }
  }

  void handleKeyRelease(String keyCode) {
    final keyUpper = NclKeys.normalizeKey(keyCode);
    scheduler.stackKeyAction('release', keyUpper);
    scheduler.tick(0);
  }

  bool handleKey(String keyCode) {
    final keyUpper = NclKeys.normalizeKey(keyCode);
    scheduler.stackKeyAction('press', keyUpper);
    scheduler.tick(0);
    if (keyUpper == NclKeys.cursorRight ||
        keyUpper == NclKeys.cursorLeft ||
        keyUpper == NclKeys.cursorUp ||
        keyUpper == NclKeys.cursorDown) {
      if (currentKeyMaster == null) {
        moveFocus(keyUpper);
      }
      return true;
    }

    if (keyUpper == NclKeys.enter) {
      handleSelection(null, NclKeys.enter);
      return true;
    }

    bool triggeredAny = false;
    for (var media in getActiveMedia()) {
      if (media.id != null) {
        final links = scheduler.getLinksForComponent(media.id!);
        final hasLink = links.any((l) => l.children.whereType<Bind>().any((b) =>
            (b.role == 'onSelection' || b.role == 'onSelect') &&
            b.component == media.id &&
            (b.children.whereType<BindParam>().any((bp) =>
                    (bp.name == 'keyCode' || bp.name == 'key') &&
                    bp.value?.toUpperCase() == keyUpper) ||
                l.children.whereType<BindParam>().any((bp) =>
                    (bp.name == 'keyCode' || bp.name == 'key') &&
                    bp.value?.toUpperCase() == keyUpper))));
        if (hasLink) {
          scheduler.triggerSelection(media.id!, keyUpper);
          triggeredAny = true;
        }
      }
    }
    return triggeredAny;
  }
}
