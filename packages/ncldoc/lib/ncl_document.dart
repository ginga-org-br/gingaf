library;

import 'dart:async';
import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';

import 'elements.dart';
import 'event.dart';
import 'ncl_pbds.dart';
import 'ncl_scheduler.dart';
import 'ncl_strings.dart';
import 'ncldoc_plugins.dart';
import 'parser.dart';

export 'package:gingacc/gingacc.dart';

export 'elements.dart';
export 'event.dart';
export 'lua_runtime.dart';
export 'ncl_pbds.dart';
export 'ncl_scheduler.dart';
export 'ncldoc_plugins.dart';
export 'parser.dart';

final _logger = Logger('ncl_doc');

class NclDocument extends GingaApp {
  late final NclPBDS pbds;
  late final Head? _head;
  late final Context _body;
  Uri? docUri;
  String get docSrc => appSrc;

  Uri? get baseUri => docUri;

  NclParser? parser;
  late final NclScheduler scheduler = NclScheduler(this);
  Users get users => gingacc.config.users;
  GingaConfig get config => gingacc.config;
  final Map<String, UserProfileQuery> _loadedProfiles = {};
  Map<String, UserProfileQuery> get loadedProfiles => _loadedProfiles;
  late final Map<String, String> _systemVariables;

  final Set<int> _breakpointLines = {};
  final Set<String> _breakpointMediaIds = {};

  Set<int> get breakpointLines => Set.unmodifiable(_breakpointLines);
  Set<String> get breakpointMediaIds => Set.unmodifiable(_breakpointMediaIds);

  void Function(Media media, NclActionType action, int line)? onBreakpointHit;

  Element? findElementByLine(int line) => parser?.findElementByLine(line);
  Media? findRelatedMedia(int line) => parser?.findRelatedMedia(line, body);
  List<Media> findRelatedMediaList(int line) =>
      parser?.findRelatedMediaList(line, body) ?? const [];
  Set<String> findRelatedMediaIds(int line) =>
      parser?.findRelatedMediaIds(line, body) ?? const {};

  void setBreakpoints(Iterable<int> lines) {
    _breakpointLines.clear();
    _breakpointMediaIds.clear();
    for (final line in lines) {
      _breakpointLines.add(line);
      _breakpointMediaIds.addAll(findRelatedMediaIds(line));
    }
  }

  void addBreakpoint(int line) {
    _breakpointLines.add(line);
    _breakpointMediaIds.addAll(findRelatedMediaIds(line));
  }

  void removeBreakpoint(int line) {
    _breakpointLines.remove(line);
    _breakpointMediaIds.clear();
    for (final l in _breakpointLines) {
      _breakpointMediaIds.addAll(findRelatedMediaIds(l));
    }
  }

  void clearBreakpoints() {
    _breakpointLines.clear();
    _breakpointMediaIds.clear();
  }

  bool hasBreakpointForMedia(Media media) {
    if (media.id != null && _breakpointMediaIds.contains(media.id)) {
      return true;
    }
    if (media.line != null && _breakpointLines.contains(media.line)) {
      return true;
    }
    return false;
  }

  bool get isPaused => scheduler.isPaused;
  set isPaused(bool val) => scheduler.isPaused = val;

  void pause() {
    scheduler.pause();
  }

  void resume() {
    scheduler.resume();
  }

  String? getSystemVariable(String name) => _systemVariables[name];

  final Map<String, List<RemoteDeviceChannel>> _remoteChannelsByClass = {};
  final Map<RemoteDeviceChannel, StreamSubscription<Map<String, dynamic>>>
      _channelMsgSubs = {};
  final Map<RemoteDeviceChannel, StreamSubscription<void>> _channelCloseSubs = {};
  StreamSubscription<void>? _gingaccRemoteSub;
  final Set<String> _disconnectedRemoteNodeIds = {};
  final Set<String> _declaredRemoteClasses = {};
  bool _multiDeviceReplicated = false;

  static ({String classId, int? deviceIndex}) parseRemoteDeviceSpec(
    String raw,
  ) {
    final trimmed = raw.trim();
    final match = RegExp(r'^([^()]+?)(?:\((\d+)\))?$').firstMatch(trimmed);
    if (match == null) {
      return (classId: trimmed, deviceIndex: null);
    }
    final classId = match.group(1)!.trim();
    final idxStr = match.group(2);
    return (
      classId: classId,
      deviceIndex: idxStr != null ? int.tryParse(idxStr) : null,
    );
  }

  bool isRemoteNodeBlocked(String? nodeId) {
    if (nodeId == null) return false;
    if (_disconnectedRemoteNodeIds.contains(nodeId)) {
      return true;
    }
    final node = getNodeById(nodeId);
    if (node is Media && getDeviceClassForMedia(node) != null) {
      return !hasConnectedRemoteDeviceForMedia(node);
    }
    return false;
  }

  bool hasConnectedRemoteDeviceForMedia(Media media) {
    final devClass = getDeviceClassForMedia(media);
    if (devClass == null || devClass.isEmpty) return false;
    return _resolveTargetChannelsForSpec(
      devClass,
      media.rawAttributes['type'],
    ).isNotEmpty;
  }

  List<RemoteDeviceChannel> _resolveTargetChannelsForSpec(
    String deviceSpec, [
    String? mimeType,
  ]) {
    final parsed = parseRemoteDeviceSpec(deviceSpec);
    final rawList = _remoteChannelsByClass[parsed.classId];
    if (rawList == null || rawList.isEmpty) return const [];
    final openMatching = rawList
        .where((ch) => !ch.isClosed && ch.supportsType(mimeType))
        .toList();
    if (parsed.deviceIndex != null) {
      final idx = parsed.deviceIndex! - 1;
      if (idx < 0 || idx >= openMatching.length) return const [];
      return [openMatching[idx]];
    }
    return openMatching;
  }

  void _refreshClassVariables(String classId) {
    final open = (_remoteChannelsByClass[classId] ?? const [])
        .where((ch) => !ch.isClosed)
        .toList();
    final devNumStr = open.length.toString();
    _systemVariables['$classId.devNumber'] = devNumStr;
    for (int i = 0; i < open.length; i++) {
      final idx = i + 1;
      _systemVariables['$classId.screenSize($idx)'] = open[i].screenSize;
      _systemVariables['$classId.screenGraphicSize($idx)'] =
          open[i].screenGraphicSize;
    }
    dispatchSettingsUpdate('$classId.devNumber', devNumStr);
  }

  void _syncGingaCcRemoteChannels() {
    if (_declaredRemoteClasses.isEmpty) return;
    for (final ch in gingacc.allRemoteDeviceChannels) {
      if (!ch.isClosed && _declaredRemoteClasses.contains(ch.deviceClass)) {
        attachRemoteDeviceChannel(ch);
      }
    }
  }

  void dispatchPropertyUpdate(
    Node targetNode,
    String propertyName,
    String value,
  ) {
    if (isRemoteNodeBlocked(targetNode.id)) return;
    targetNode.setPropertyValue(propertyName, value);
    if (targetNode is Media) {
      scheduler.stackNclAction(
        targetNode.getPropertyNclEvent(propertyName),
        NclActionType.set,
        value: value,
      );
      final devClass = getDeviceClassForMedia(targetNode);
      if (devClass != null && targetNode.id != null) {
        notifyRemoteNodeAction(
          deviceClass: devClass,
          nodeId: targetNode.id!,
          label: propertyName,
          eventType: 'attribution',
          action: 'set',
          value: value,
          mimeType: targetNode.rawAttributes['type'],
        );
      }
    }
    if (targetNode is NCLua) {
      targetNode.runtime.postNclEvent({
        'class': 'ncl',
        'type': 'attribution',
        'action': 'start',
        'name': propertyName,
        'value': value,
      });
    }
  }

  void attachRemoteDeviceChannel(RemoteDeviceChannel channel) {
    final parsed = parseRemoteDeviceSpec(channel.deviceClass);
    final baseClass = parsed.classId;
    final list = _remoteChannelsByClass.putIfAbsent(
      baseClass,
      () => <RemoteDeviceChannel>[],
    );
    if (list.contains(channel)) {
      _refreshClassVariables(baseClass);
      return;
    }
    list.add(channel);
    _disconnectedRemoteNodeIds.clear();
    _refreshClassVariables(baseClass);

    _channelMsgSubs[channel] = channel.onDeviceMessage.listen((msg) {
      handleRemoteTransitionMetadata(msg);
    });
    _channelCloseSubs[channel] = channel.onClose.listen((_) {
      _handleRemoteDeviceDisconnected(channel, baseClass);
    });
  }

  void _handleRemoteDeviceDisconnected(
    RemoteDeviceChannel channel,
    String baseClass,
  ) {
    final list = _remoteChannelsByClass[baseClass];
    final channelIndex = list != null ? list.indexOf(channel) + 1 : -1;

    final affectedMedia = <Media>[];
    for (final media in _body.descendants.whereType<Media>()) {
      final devSpec = getDeviceClassForMedia(media);
      if (devSpec == null || media.id == null) continue;
      final parsed = parseRemoteDeviceSpec(devSpec);
      if (parsed.classId != baseClass) continue;
      if (parsed.deviceIndex == null || parsed.deviceIndex == channelIndex) {
        affectedMedia.add(media);
      }
    }

    for (final media in affectedMedia) {
      final mainEvt = media.getMainNclEvent();
      if (mainEvt.state == NclStateType.occurring ||
          mainEvt.state == NclStateType.paused) {
        scheduler.stackNclAction(mainEvt, NclActionType.abort);
      }
    }
    if (affectedMedia.isNotEmpty) {
      scheduler.tick(0);
      for (final media in affectedMedia) {
        _disconnectedRemoteNodeIds.add(media.id!);
      }
    }

    list?.remove(channel);
    _channelMsgSubs.remove(channel)?.cancel();
    _channelCloseSubs.remove(channel)?.cancel();
    _refreshClassVariables(baseClass);
  }

  void replicateMultiDeviceNodes() {
    if (_multiDeviceReplicated) return;
    _multiDeviceReplicated = true;
    _syncGingaCcRemoteChannels();

    final contextsToScan = <Context>[
      _body,
      ..._body.descendants.whereType<Context>(),
    ];

    for (final ctx in contextsToScan) {
      final mediaList = ctx.children.whereType<Media>().toList();
      for (final media in mediaList) {
        final origId = media.id;
        if (origId == null || origId.isEmpty) continue;
        final devSpec = getDeviceClassForMedia(media);
        if (devSpec == null || devSpec.isEmpty) continue;

        final parsed = parseRemoteDeviceSpec(devSpec);
        if (parsed.deviceIndex != null) {
          continue;
        }

        final matching = _resolveTargetChannelsForSpec(
          parsed.classId,
          media.rawAttributes['type'],
        );

        if (matching.length <= 1) {
          continue;
        }

        final replicatedMedia = <Media>[];
        final replicatedAreaIds = <String>{};
        for (final area in media.children.whereType<Area>()) {
          if (area.id != null && area.id!.isNotEmpty) {
            replicatedAreaIds.add(area.id!);
          }
        }

        for (int k = 0; k < matching.length; k++) {
          final suffix = 'RD${k.toString().padLeft(2, '0')}';
          final newMediaId = '$origId$suffix';
          final attrs = Map<String, String>.from(media.rawAttributes);
          attrs['id'] = newMediaId;
          final clone = Media(rawAttributes: attrs)
            ..xmlTagName = media.xmlTagName
            ..line = media.line
            ..parent = ctx;

          bool setDeviceProp = false;
          for (final child in media.children) {
            if (child is Property) {
              final pAttrs = Map<String, String>.from(child.rawAttributes);
              if (child.name == 'device') {
                pAttrs['value'] = '${parsed.classId}(${k + 1})';
                setDeviceProp = true;
              }
              final pClone = Property(rawAttributes: pAttrs)
                ..xmlTagName = child.xmlTagName
                ..line = child.line
                ..parent = clone;
              clone.children.add(pClone);
            } else if (child is Area) {
              final aAttrs = Map<String, String>.from(child.rawAttributes);
              if (child.id != null && child.id!.isNotEmpty) {
                aAttrs['id'] = '${child.id}$suffix';
              }
              final aClone = Area(rawAttributes: aAttrs)
                ..xmlTagName = child.xmlTagName
                ..line = child.line
                ..parent = clone;
              clone.children.add(aClone);
            }
          }
          if (!setDeviceProp) {
            final devProp = Property(
              rawAttributes: {
                'name': 'device',
                'value': '${parsed.classId}(${k + 1})',
              },
            )
              ..xmlTagName = 'property'
              ..parent = clone;
            clone.children.add(devProp);
          }
          replicatedMedia.add(clone);
        }

        final mediaIdx = ctx.children.indexOf(media);
        if (mediaIdx != -1) {
          ctx.children.removeAt(mediaIdx);
          ctx.children.insertAll(mediaIdx, replicatedMedia);
        }

        final ports = ctx.children
            .whereType<Port>()
            .where((p) => p.component == origId)
            .toList();
        for (final port in ports) {
          final portIdx = ctx.children.indexOf(port);
          final clonedPorts = <Port>[];
          for (int k = 0; k < matching.length; k++) {
            final suffix = 'RD${k.toString().padLeft(2, '0')}';
            final pAttrs = Map<String, String>.from(port.rawAttributes);
            if (port.id != null && port.id!.isNotEmpty) {
              pAttrs['id'] = '${port.id}$suffix';
            }
            pAttrs['component'] = '$origId$suffix';
            final iface = port.interface;
            if (iface != null && replicatedAreaIds.contains(iface)) {
              pAttrs['interface'] = '$iface$suffix';
            }
            clonedPorts.add(
              Port(rawAttributes: pAttrs)
                ..xmlTagName = port.xmlTagName
                ..line = port.line
                ..parent = ctx,
            );
          }
          if (portIdx != -1) {
            ctx.children.removeAt(portIdx);
            ctx.children.insertAll(portIdx, clonedPorts);
          }
        }

        final links = ctx.children
            .whereType<Link>()
            .where((l) => l.binds.any((b) => b.component == origId))
            .toList();
        for (final link in links) {
          final linkIdx = ctx.children.indexOf(link);
          final clonedLinks = <Link>[];
          for (int k = 0; k < matching.length; k++) {
            final suffix = 'RD${k.toString().padLeft(2, '0')}';
            final lAttrs = Map<String, String>.from(link.rawAttributes);
            if (link.id != null && link.id!.isNotEmpty) {
              lAttrs['id'] = '${link.id}$suffix';
            }
            final lClone = Link(rawAttributes: lAttrs)
              ..xmlTagName = link.xmlTagName
              ..line = link.line
              ..parent = ctx;
            for (final child in link.children) {
              if (child is Bind) {
                final bAttrs = Map<String, String>.from(child.rawAttributes);
                if (child.component == origId) {
                  bAttrs['component'] = '$origId$suffix';
                  final iface = child.interface;
                  if (iface != null && replicatedAreaIds.contains(iface)) {
                    bAttrs['interface'] = '$iface$suffix';
                  }
                }
                final bClone = Bind(rawAttributes: bAttrs)
                  ..xmlTagName = child.xmlTagName
                  ..line = child.line
                  ..parent = lClone;
                for (final bp in child.children.whereType<BindParam>()) {
                  bClone.children.add(
                    BindParam(
                      rawAttributes: Map<String, String>.from(bp.rawAttributes),
                    )
                      ..xmlTagName = bp.xmlTagName
                      ..line = bp.line
                      ..parent = bClone,
                  );
                }
                lClone.children.add(bClone);
              }
            }
            clonedLinks.add(lClone);
          }
          if (linkIdx != -1) {
            ctx.children.removeAt(linkIdx);
            ctx.children.insertAll(linkIdx, clonedLinks);
          }
        }
      }
    }
  }

  void handleRemoteTransitionMetadata(Map<String, dynamic> msg) {
    final nodeId = (msg['nodeId'] ?? msg['sceneNodeId'])?.toString();
    if (nodeId == null || nodeId.isEmpty) return;
    final node = getNodeById(nodeId);
    if (node == null) return;
    final label = (msg['label'] ?? msg['hotspotId'] ?? msg['interfaceId'])
        ?.toString();
    final eventType = msg['eventType']?.toString() ??
        (msg['type'] == 'ncl360_view_event' ? 'view' : 'presentation');
    final transition = msg['transition']?.toString() ??
        msg['action']?.toString() ??
        (msg['inView'] == true ? 'starts' : 'stops');

    if (eventType == 'view') {
      final inView =
          transition == 'starts' || transition == 'start' || msg['inView'] == true;
      handleViewTransition(nodeId, inView, label);
    } else if (eventType == 'selection') {
      if (transition == 'starts' || transition == 'start') {
        handleSelection(nodeId);
      }
    } else if (eventType == 'attribution') {
      if (label != null && label.isNotEmpty) {
        final val = msg['value']?.toString() ?? '';
        node.setPropertyValue(label, val);
        scheduler.stackNclAction(
          node.getPropertyNclEvent(label),
          NclActionType.set,
          value: val,
        );
        scheduler.tick(0);
      }
    } else if (eventType == 'presentation') {
      final targetEvt =
          (label != null && label.isNotEmpty && label != 'main')
              ? node.getAreaNclEvent(label)
              : node.getMainNclEvent();
      if (transition == 'starts' || transition == 'start') {
        if (targetEvt.state != NclStateType.occurring) {
          scheduler.stackNclAction(targetEvt, NclActionType.start);
          scheduler.tick(0);
        }
      } else if (transition == 'stops' || transition == 'stop') {
        if (targetEvt.state != NclStateType.sleeping) {
          scheduler.stackNclAction(targetEvt, NclActionType.stop);
          scheduler.tick(0);
        }
      } else if (transition == 'pauses' || transition == 'pause') {
        if (targetEvt.state != NclStateType.paused) {
          scheduler.stackNclAction(targetEvt, NclActionType.pause);
          scheduler.tick(0);
        }
      } else if (transition == 'resumes' || transition == 'resume') {
        if (targetEvt.state == NclStateType.paused) {
          scheduler.stackNclAction(targetEvt, NclActionType.resume);
          scheduler.tick(0);
        }
      } else if (transition == 'aborts' || transition == 'abort') {
        if (targetEvt.state != NclStateType.sleeping) {
          scheduler.stackNclAction(targetEvt, NclActionType.abort);
          scheduler.tick(0);
        }
      }
    }
  }

  void notifyRemoteNodePreparation(Media media) {
    final devClass = getDeviceClassForMedia(media);
    final nodeId = media.id;
    if (devClass == null || nodeId == null || isRemoteNodeBlocked(nodeId)) {
      return;
    }
    final channels = _resolveTargetChannelsForSpec(
      devClass,
      media.rawAttributes['type'],
    );
    if (channels.isEmpty) return;

    final props = <Map<String, String>>[];
    for (final p in media.getProperties()) {
      if (p.name != null && p.name != 'src') {
        props.add({'name': p.name!, 'value': p.value ?? ''});
      }
    }
    String? resolvedNodeSrc = media.src;
    if (resolvedNodeSrc != null &&
        resolvedNodeSrc.isNotEmpty &&
        !isHttpUri(resolvedNodeSrc) &&
        !resolvedNodeSrc.startsWith('file:')) {
      final resolvedUri = appContext.resolveUri(
        resolvedNodeSrc,
        baseUri?.toString() ?? docSrc,
      );
      if (resolvedUri.isScheme('http') || resolvedUri.isScheme('https')) {
        resolvedNodeSrc = resolvedUri.toString();
      } else if (docSrc.isNotEmpty && !docSrc.trim().startsWith('<')) {
        final normDoc = docSrc.replaceAll('\\', '/');
        final slashIdx = normDoc.lastIndexOf('/');
        if (slashIdx != -1) {
          resolvedNodeSrc =
              '${normDoc.substring(0, slashIdx + 1)}$resolvedNodeSrc';
        }
      }
    }
    final nodeMetadata = <String, dynamic>{
      'nodeId': nodeId,
      if (resolvedNodeSrc != null) 'nodeSrc': resolvedNodeSrc,
      if (media.src != null) 'rawNodeSrc': media.src,
      'appId': applicationId,
      'type': media.rawAttributes['type'] ??
          ((media.src?.endsWith('.ncl360') ?? false)
              ? 'application/x-ncl360'
              : 'application/octet-stream'),
      if (props.isNotEmpty) 'properties': props,
    };
    for (final ch in channels) {
      ch.sendToDevice(nodeMetadata);
    }
  }

  void notifyRemoteNodeAction({
    required String deviceClass,
    required String nodeId,
    String? label,
    required String eventType,
    required String action,
    String? value,
    String? mimeType,
    int delay = 0,
  }) {
    if (isRemoteNodeBlocked(nodeId)) return;
    final channels = _resolveTargetChannelsForSpec(deviceClass, mimeType);
    if (channels.isEmpty) return;
    final actionMetadata = <String, dynamic>{
      'nodeId': nodeId,
      if (label != null && label.isNotEmpty) 'label': label,
      'appId': applicationId,
      'eventType': eventType,
      'action': action,
      if (value != null) 'value': value,
      if (delay > 0) 'delay': delay,
    };
    for (final ch in channels) {
      ch.sendToDevice(actionMetadata);
    }
  }

  void dispatchSettingsUpdate(
    String name,
    String value, {
    String? userId,
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
    for (final s in body.descendants
        .whereType<Media>()
        .where((node) => node is Settings || node is UserSettings)) {
      if (userId != null) {
        bool matchesUser = false;
        if (s is UserSettings) {
          if (s.user == userId) {
            matchesUser = true;
          } else if (userId == 'currentUser') {
            final currentUser = users.currentUser;
            if (currentUser != null && _isUserProfile(s.user)) {
              final profile = _loadedProfiles[s.user];
              if (profile != null &&
                  users.evaluateProfileForUser(profile, currentUser.id)) {
                matchesUser = true;
              }
            }
          }
        }
        if (matchesUser) {
          final prop = s.children
              .whereType<Property>()
              .where((p) => p.name == name)
              .firstOrNull;
          if (prop != null) {
            if (prop.value == value) {
              continue;
            }
            dispatchPropertyUpdate(s, name, value);
          }
        }
      } else {
        final prop = s.children
            .whereType<Property>()
            .where((p) => p.name == name)
            .firstOrNull;
        if (prop != null) {
          if (prop.value == value) {
            continue;
          }
          dispatchPropertyUpdate(s, name, value);
        }
      }
    }
    onStateChanged?.call();
  }

  void Function()? onStateChanged;

  static Future<NclDocument> fromSrc(
    String appSrc, {
    String? applicationId,
    GingaCC? gingacc,
    String? baseDirSrc,
  }) async {
    _logger.info('Loading NCL document from src: $appSrc');
    final effectiveId = applicationId ?? appSrc;
    final cc = gingacc ?? GingaCC();
    final ctx = cc.getAppContext(appContextId: effectiveId);
    final String? xml;
    if (isXmlString(appSrc)) {
      xml = appSrc;
    } else {
      final docUri = ctx.resolveUri(appSrc, baseDirSrc);
      xml = (await ctx.loadContent(docUri, baseDirSrc)) ??
          (await ctx.loadContent(appSrc, baseDirSrc));
    }

    final doc = NclDocument.fromContent(
      xml ?? '',
      applicationId: effectiveId,
      appSrc: appSrc,
      gingacc: cc,
      baseDirSrc: baseDirSrc,
    );
    await doc.loadUserProfiles();
    return doc;
  }

  factory NclDocument.fromContent(
    String xml, {
    String? applicationId,
    String? appSrc,
    String? docSrc,
    Map<String, String>? virtualFiles,
    GingaCC? gingacc,
    String? baseDirSrc,
  }) {
    if (xml.trim().isEmpty) {
      throw ArgumentError('empty src');
    }
    final resolvedAppSrc = appSrc ?? docSrc ?? 'tmp.ncl';
    final effectiveId = applicationId ?? resolvedAppSrc;
    final cc = gingacc ?? GingaCC();
    final ctx = cc.getAppContext(
      appContextId: effectiveId,
      virtualFiles: virtualFiles,
    );
    final Uri? resolvedUri = (!isXmlString(resolvedAppSrc))
        ? ctx.resolveUri(resolvedAppSrc, baseDirSrc)
        : null;
    if (resolvedUri != null && ctx.baseUri == null) {
      ctx.baseUri = resolvedUri;
    }
    final doc = NclDocument._(
      applicationId: effectiveId,
      appSrc: resolvedAppSrc,
      docUri: resolvedUri,
      gingacc: cc,
    );
    final parser = NclParser(
      docUri: resolvedUri,
      document: doc,
    );
    final (head, body) = parser.parseString(xml);
    doc.parser = parser;
    doc._init(head: head, body: body);
    return doc;
  }

  NclDocument._({
    String? applicationId,
    required super.appSrc,
    this.docUri,
    super.gingacc,
  }) : super(
          applicationId: applicationId ?? appSrc,
          baseUri: docUri,
        ) {
    pbds = NclPBDS(
      id: this.applicationId,
      baseUri: docUri,
    );
    _systemVariables = {
      ...gingacc.config.systemVariables,
    };
    gingacc.config.onVariableChanged.listen(
      (evt) => _onConfigVariableChanged(evt.name, evt.value, evt.userId),
    );
  }

  void _onConfigVariableChanged(String name, String value, String? userId) {
    dispatchSettingsUpdate(name, value, userId: userId);
    for (final sw in _body.descendants.whereType<Switch>()) {
      if (sw.getMainState() == NclStateType.occurring) {
        final desired = resolveSwitch(sw);
        for (final child in sw.children.whereType<Node>()) {
          if (child == desired &&
              child.getMainState() != NclStateType.occurring) {
            scheduler.stackNclAction(
              child.getMainNclEvent(),
              NclActionType.start,
            );
          } else if (child != desired &&
              child.getMainState() == NclStateType.occurring) {
            scheduler.stackNclAction(
              child.getMainNclEvent(),
              NclActionType.stop,
            );
          }
        }
        scheduler.tick(0);
      }
    }
  }

  void _init({Head? head, required Body body}) {
    _head = head;
    _body = body;
    pbds.addDocument(applicationId, document: this);
    for (final s in body.descendants.whereType<Settings>()) {
      for (final p in s.children.whereType<Property>()) {
        if (p.name != null && p.value != null && p.value!.isNotEmpty) {
          _systemVariables[p.name!] = p.value!;
        }
      }
    }
    _initMultiDeviceVariables();
    _syncGingaCcRemoteChannels();
    _gingaccRemoteSub = gingacc.onRemoteDevicesChanged.listen((_) {
      _syncGingaCcRemoteChannels();
    });
    loadUserProfiles();
  }

  void _initMultiDeviceVariables() {
    _declaredRemoteClasses.clear();
    for (final rb in headChildren.whereType<RegionBase>()) {
      final dev = rb.device;
      if (dev != null && dev.isNotEmpty) {
        _declaredRemoteClasses.add(parseRemoteDeviceSpec(dev).classId);
      }
    }
    for (final media in _body.descendants.whereType<Media>()) {
      final dev = getDeviceClassForMedia(media);
      if (dev != null && dev.isNotEmpty) {
        _declaredRemoteClasses.add(parseRemoteDeviceSpec(dev).classId);
      }
    }
    final allClasses = <String>{
      ..._declaredRemoteClasses,
      ..._remoteChannelsByClass.keys,
    };
    for (final classId in allClasses) {
      _refreshClassVariables(classId);
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
              if (id != null &&
                  id.isNotEmpty &&
                  src != null &&
                  src.isNotEmpty) {
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
      String? jsonContent = appContext.loadContentSync(src, docSrc);
      if (jsonContent == null || jsonContent.isEmpty) {
        final profileUri = appContext.resolveUri(src, docSrc);
        jsonContent = await appContext.loadContent(profileUri);
      }
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

  bool isUserProfile(String id) => _isUserProfile(id);

  bool compareValues(String? actual, String expected, String comparator) {
    final val = actual ?? '';
    switch (comparator) {
      case 'eq':
        return val == expected;
      case 'ne':
        return val != expected;
      case 'gt':
        final n1 = double.tryParse(val);
        final n2 = double.tryParse(expected);
        if (n1 != null && n2 != null) return n1 > n2;
        return val.compareTo(expected) > 0;
      case 'lt':
        final n1 = double.tryParse(val);
        final n2 = double.tryParse(expected);
        if (n1 != null && n2 != null) return n1 < n2;
        return val.compareTo(expected) < 0;
      case 'gte':
        final n1 = double.tryParse(val);
        final n2 = double.tryParse(expected);
        if (n1 != null && n2 != null) return n1 >= n2;
        return val.compareTo(expected) >= 0;
      case 'lte':
        final n1 = double.tryParse(val);
        final n2 = double.tryParse(expected);
        if (n1 != null && n2 != null) return n1 <= n2;
        return val.compareTo(expected) <= 0;
    }
    return false;
  }

  bool _evaluateRuleElement(Element ruleEl) {
    try {
      for (final plugin in GetIt.instance.getAll<NclRulePlugin>()) {
        final result = plugin.evaluate(ruleEl, this);
        if (result != null) {
          return result;
        }
      }
    } catch (_) {}
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
      final userAttr = ruleEl.rawAttributes['user'];
      var systemVal = userAttr != null && userAttr.isNotEmpty
          ? null
          : _systemVariables[varName];

      // NOT COMPLIANT: <rule> with user
      if (systemVal == null && userAttr != null && userAttr.isNotEmpty) {
        if (_isUserProfile(userAttr)) {
          final profile = _loadedProfiles[userAttr];
          final currentUser = users.currentUser;
          if (currentUser != null &&
              profile != null &&
              !users.evaluateProfileForUser(profile, currentUser.id)) {
            return false;
          }
          systemVal = currentUser?.getProperty(varName)?.toString();
        }
        if (systemVal == null) {
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

      return compareValues(systemVal, value, comparator);
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
            final currentUser = users.currentUser;
            if (currentUser != null &&
                profile != null &&
                users.evaluateProfileForUser(profile, currentUser.id)) {
              targetUser = currentUser;
            } else if (currentUser != null && profile != null) {
              return null;
            } else {
              final prop = node.children
                  .whereType<Property>()
                  .where((p) => p.name == propertyName)
                  .firstOrNull;
              if (prop != null && prop.value != null) {
                return prop.value;
              }
              targetUser = profile != null
                  ? users.getMatchingUsersForProfile(profile).firstOrNull
                  : (users.getUser(userAttr) ?? users.currentUser);
            }
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

  void start() {
    replicateMultiDeviceNodes();
    scheduler.start();
    _initInitialFocus();
  }

  void stop() {
    scheduler.stop();
    for (final lua in _body.descendants.whereType<NCLua>()) {
      lua.runtime.dispose();
    }
    _gingaccRemoteSub?.cancel();
    _gingaccRemoteSub = null;
    for (final sub in _channelMsgSubs.values) {
      sub.cancel();
    }
    _channelMsgSubs.clear();
    for (final sub in _channelCloseSubs.values) {
      sub.cancel();
    }
    _channelCloseSubs.clear();
  }

  Set<Media> tick([int incrementMs = 0, int stepMs = 100]) {
    final res = scheduler.tick(incrementMs, stepMs);
    _initInitialFocus();
    return res;
  }

  void _initInitialFocus() {
    final active = getActiveMedia();
    final currentActiveFocus = _currentFocusNodeId != null
        ? active.where((m) => m.id == _currentFocusNodeId).firstOrNull
        : null;
    if (currentActiveFocus == null) {
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
    }
  }

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

  RegionBase? getRegionBaseForMedia(Media media) {
    final desc = getDescriptorForMedia(media);
    final regionId = desc?.region;
    if (regionId == null || regionId.isEmpty) return null;
    Element? current = getElementById(regionId);
    while (current != null) {
      if (current is RegionBase) return current;
      if (current.xmlTagName == 'regionBase') {
        return RegionBase(rawAttributes: current.rawAttributes);
      }
      current = current.parent;
    }
    return null;
  }

  String? getDeviceClassForMedia(Media media) {
    final propDevice = getPropertyValue(media, 'device');
    if (propDevice != null && propDevice.isNotEmpty) {
      if (propDevice.trim().toLowerCase() == 'local') return null;
      return propDevice;
    }
    final propClass = getPropertyValue(media, 'deviceClass');
    if (propClass != null && propClass.isNotEmpty) {
      return propClass;
    }
    final rb = getRegionBaseForMedia(media);
    if (rb?.device != null && rb!.device!.isNotEmpty) {
      return rb.device;
    }
    return null;
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
    dispatchSettingsUpdate('service.currentFocus', actualId);
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
      if (onStateChanged != null) {
        onStateChanged!.call();
      } else {
        scheduler.tick(0);
      }
    }
  }

  void handleViewTransition(String componentId, bool inView,
      [String? interfaceId]) {
    scheduler.triggerViewTransition(componentId, inView, interfaceId);
    if (onStateChanged != null) {
      onStateChanged!.call();
    } else {
      scheduler.tick(0);
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
    try {
      for (final plugin in GetIt.instance.getAll<NclKeyPlugin>()) {
        if (plugin.onKey(keyUpper, 'press', this)) {
          onStateChanged?.call();
          return true;
        }
      }
    } catch (_) {}
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
