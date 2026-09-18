library;

import 'dart:async';
import 'dart:convert';

import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';

import 'elements.dart';
import 'event.dart';
import 'ncl_scheduler.dart';
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
  late final Settings _settings;
  Uri? docUri;
  final String docSrc;

  late final NclScheduler scheduler = NclScheduler(this);
  Users get users => gingacc.config.users;
  GingaConfig get config => gingacc.config;
  final Map<String, UserProfileQuery> _loadedProfiles = {};
  Map<String, UserProfileQuery> get loadedProfiles => _loadedProfiles;
  late final Map<String, String> envVariables;
  Map<String, String> get systemVariables => envVariables;
  Map<String, String> get systemProperties => envVariables;

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
  }) : gingacc = gingacc ?? GingaCC() {
    envVariables = this.gingacc.config.envVariables;
  }

  void _init({Head? head, required Body body}) {
    _head = head;
    _body = body;
    _gatherSettings();
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
  NclStateType getBodyState() => _body.getMainState();

  Settings getSettings() => _settings;

  void doNclEditingCommand(String command) {
    NclParser(docUri: docUri, document: this).doNclEditingCommand(this, command);
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
      // NOT COMPLIANT: <rule> with user
      final userAttr = ruleEl.rawAttributes['user'];
      // NOT COMPLIANT ends
      var systemVal = envVariables[varName];
      if (systemVal == null) {
        for (final s in getAllSettingsNodes()) {
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

      if (varName == 'service.currentFocus') {
        final currentFocus = systemVal ??
            envVariables['service.currentFocus'] ??
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

  bool _hasUserSettingsMedia(Element root) {
    if (root.rawAttributes['type'] == 'application/x-ncl-user-settings' &&
        root.rawAttributes['user'] == 'currentUser') {
      return true;
    }
    return root.descendants.any((child) =>
        child.rawAttributes['type'] == 'application/x-ncl-user-settings' &&
        child.rawAttributes['user'] == 'currentUser');
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

  List<Settings> getAllSettingsNodes() {
    final list = <Settings>[];
    void search(Element el) {
      if (el is Settings) list.add(el);
      for (var c in el.children) {
        search(c);
      }
    }

    search(_body);
    return list;
  }

  void setFocus(String mediaId) {
    if (mediaId.isEmpty) return;
    var actualId = mediaId;
    final mediaByIndex = getActiveMediaByFocusIndex(mediaId);
    if (mediaByIndex != null && mediaByIndex.id != null) {
      actualId = mediaByIndex.id!;
    }
    _currentFocusNodeId = actualId;
    envVariables['service.currentFocus'] = actualId;
    for (var node in getAllSettingsNodes()) {
      node.setPropertyValue('service.currentFocus', actualId);
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
          final fa = int.tryParse(getFocusIndexForMedia(a)!) ?? 9999;
          final fb = int.tryParse(getFocusIndexForMedia(b)!) ?? 9999;
          return fa.compareTo(fb);
        });
        setFocus(focusable.first.id ?? '');
      }
      return;
    }

    final desc = getDescriptorForMedia(currentMedia);
    if (desc == null) return;

    String? targetIndex;
    final dir = direction.toUpperCase();
    if (dir == 'RIGHT' || dir == 'CURSOR_RIGHT') {
      targetIndex = desc.moveRight;
    } else if (dir == 'LEFT' || dir == 'CURSOR_LEFT') {
      targetIndex = desc.moveLeft;
    } else if (dir == 'UP' || dir == 'CURSOR_UP') {
      targetIndex = desc.moveUp;
    } else if (dir == 'DOWN' || dir == 'CURSOR_DOWN') {
      targetIndex = desc.moveDown;
    }

    if (targetIndex != null && targetIndex.isNotEmpty) {
      final targetMedia = getActiveMediaByFocusIndex(targetIndex);
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

  bool handleKey(String keyCode) {
    final keyUpper = keyCode.toUpperCase();
    if (keyUpper == 'RIGHT' ||
        keyUpper == 'CURSOR_RIGHT' ||
        keyUpper == 'LEFT' ||
        keyUpper == 'CURSOR_LEFT' ||
        keyUpper == 'UP' ||
        keyUpper == 'CURSOR_UP' ||
        keyUpper == 'DOWN' ||
        keyUpper == 'CURSOR_DOWN') {
      moveFocus(keyUpper);
      return true;
    }

    if (keyUpper == 'ENTER' || keyUpper == 'OK' || keyUpper == 'SELECT') {
      handleSelection(null, 'ENTER');
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
