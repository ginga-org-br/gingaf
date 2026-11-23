import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:nclui/ncl_widget.dart';
import 'package:plugins/ncl360_plugin.dart';

class RemoteDevicePlayerWidget extends StatefulWidget {
  final GingaCC gingacc;
  final String deviceClass;
  final List<String> supportedTypes;
  final String? baseDirSrc;
  final Map<String, String>? virtualFiles;
  final bool useSsdpDiscovery;
  final int ssdpPort;
  final bool useRealWebSocket;
  final String screenSize;

  const RemoteDevicePlayerWidget({
    super.key,
    required this.gingacc,
    required this.deviceClass,
    this.supportedTypes = const [
      'application/x-ncl360',
      'text/html',
      'application/x-ginga-NCL',
      'application/x-vlibras-gloss',
      'application/ttml+xml',
      'text/srt',
      'video/mp4',
      'audio/mpeg',
      'text/plain',
    ],
    this.baseDirSrc,
    this.virtualFiles,
    this.useSsdpDiscovery = false,
    this.ssdpPort = ssdpDefaultPort,
    this.useRealWebSocket = false,
    this.screenSize = '1280, 720',
  });

  @override
  State<RemoteDevicePlayerWidget> createState() =>
      RemoteDevicePlayerWidgetState();
}

class RemoteDevicePlayerWidgetState extends State<RemoteDevicePlayerWidget> {
  late final RemoteDeviceClient _client;
  StreamSubscription<Map<String, dynamic>>? _nodeSub;
  StreamSubscription<Map<String, dynamic>>? _actionSub;
  StreamSubscription<RemoteDeviceState>? _stateSub;

  GlobalKey<HtmlWidgetState> _htmlKey = GlobalKey<HtmlWidgetState>();
  int _rendererEpoch = 0;

  String? _activeNodeId;
  String? _activeNodeSrc;
  String? _activeNodeType;
  String _activeAppId = 'default';
  bool _isPlaying = false;
  final Map<String, String> _properties = {};
  final List<Map<String, dynamic>> _receivedActions = [];

  RemoteDeviceClient get client => _client;
  String? get activeNodeId => _activeNodeId;
  String? get activeNodeSrc => _activeNodeSrc;
  String? get activeNodeType => _activeNodeType;
  bool get isPlaying => _isPlaying;
  Map<String, String> get properties => Map.unmodifiable(_properties);
  List<Map<String, dynamic>> get receivedActions =>
      List.unmodifiable(_receivedActions);

  @override
  void initState() {
    super.initState();
    _client = RemoteDeviceClient(
      gingacc: widget.gingacc,
      deviceClass: widget.deviceClass,
      supportedTypes: widget.supportedTypes,
      screenSize: widget.screenSize,
      screenGraphicSize: widget.screenSize,
      useSsdpDiscovery: widget.useSsdpDiscovery,
      ssdpPort: widget.ssdpPort,
      useRealWebSocket: widget.useRealWebSocket,
    );
    _nodeSub = _client.onNodeMetadata.listen(_handleNodeMetadata);
    _actionSub = _client.onActionMetadata.listen(_handleActionMetadata);
    _stateSub = _client.onStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_client.register());
  }

  String _resolveSrc(String rawSrc) {
    if (isHttpUri(rawSrc) ||
        rawSrc.startsWith('file:') ||
        rawSrc.startsWith('data:') ||
        rawSrc.startsWith('/')) {
      return rawSrc;
    }
    final base = widget.baseDirSrc ?? widget.gingacc.config.appSrc;
    if (base != null && base.isNotEmpty) {
      final normalizedBase = base.replaceAll('\\', '/');
      if (!isHttpUri(normalizedBase) && !normalizedBase.startsWith('file:')) {
        final slashIdx = normalizedBase.lastIndexOf('/');
        if (slashIdx != -1) {
          return '${normalizedBase.substring(0, slashIdx + 1)}$rawSrc';
        }
      }
      return widget.gingacc.resolveUri(rawSrc, base).toString();
    }
    return rawSrc;
  }

  void _handleNodeMetadata(Map<String, dynamic> msg) {
    final nodeId = msg['nodeId']?.toString();
    if (nodeId == null || nodeId.isEmpty) return;
    final rawSrc = msg['nodeSrc']?.toString();
    final nodeType = msg['type']?.toString();
    final appId = msg['appId']?.toString() ?? _activeAppId;
    final nextProps = <String, String>{};
    final rawProps = msg['properties'];
    if (rawProps is List) {
      for (final p in rawProps.whereType<Map>()) {
        final name = p['name']?.toString();
        if (name != null && name.isNotEmpty) {
          nextProps[name] = p['value']?.toString() ?? '';
        }
      }
    }

    if (mounted) {
      setState(() {
        _activeNodeId = nodeId;
        _activeNodeSrc =
            rawSrc != null && rawSrc.isNotEmpty ? _resolveSrc(rawSrc) : null;
        _activeNodeType = nodeType;
        _activeAppId = appId;
        _properties
          ..clear()
          ..addAll(nextProps);
      });
    }

    _htmlKey.currentState?.dispatchRemoteMetadata(msg);
  }

  void _handleActionMetadata(Map<String, dynamic> msg) {
    _receivedActions.add(Map<String, dynamic>.from(msg));
    final eventType = msg['eventType']?.toString();
    final action = msg['action']?.toString();
    final nodeId = msg['nodeId']?.toString() ?? _activeNodeId;

    if (eventType == 'presentation' && nodeId != null) {
      if (action == 'start' || action == 'resume') {
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pushInitialPropertiesToHtml();
          _htmlKey.currentState?.dispatchRemoteMetadata(msg);
        });
      } else if (action == 'stop' || action == 'abort') {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } else if (action == 'pause') {
        _htmlKey.currentState?.dispatchRemoteMetadata(msg);
      }
    } else if (eventType == 'attribution') {
      final label = msg['label']?.toString();
      final value = msg['value']?.toString() ?? '';
      if (label != null && label.isNotEmpty) {
        if (mounted) {
          setState(() {
            _properties[label] = value;
          });
        }
        _htmlKey.currentState?.dispatchRemoteMetadata(msg);
      }
    }
  }

  void _pushInitialPropertiesToHtml() {
    if (_activeNodeId == null || _properties.isEmpty) return;
    _htmlKey.currentState?.dispatchRemoteMetadata({
      'nodeId': _activeNodeId,
      if (_activeNodeSrc != null) 'nodeSrc': _activeNodeSrc,
      'appId': _activeAppId,
      'type': _activeNodeType ?? 'text/html',
      'properties': _properties.entries
          .map((e) => {'name': e.key, 'value': e.value})
          .toList(),
    });
  }

  Future<void> restart() async {
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _activeNodeId = null;
      _activeNodeSrc = null;
      _activeNodeType = null;
      _properties.clear();
      _receivedActions.clear();
      _rendererEpoch++;
      _htmlKey = GlobalKey<HtmlWidgetState>();
    });
    await _client.deregister();
    if (!mounted) return;
    await _client.register();
    if (mounted) {
      setState(() {});
    }
  }

  void sendViewTransition(String hotspotId, bool inView) {
    if (_activeNodeId == null) return;
    _client.sendTransitionMetadata(
      nodeId: _activeNodeId!,
      appId: _activeAppId,
      eventType: 'view',
      transition: inView ? 'starts' : 'stops',
      label: hotspotId,
    );
  }

  void sendSelectionTransition([String? label]) {
    if (_activeNodeId == null) return;
    _client.sendTransitionMetadata(
      nodeId: _activeNodeId!,
      appId: _activeAppId,
      eventType: 'selection',
      transition: 'starts',
      label: label,
    );
  }

  @override
  void dispose() {
    _nodeSub?.cancel();
    _actionSub?.cancel();
    _stateSub?.cancel();
    unawaited(_client.dispose());
    super.dispose();
  }

  String? _lookupVirtualContent(String src) {
    final files = widget.virtualFiles;
    if (files != null && files.isNotEmpty) {
      if (files.containsKey(src)) return files[src];
      final baseName = src.split('/').last;
      for (final entry in files.entries) {
        final key = entry.key.replaceAll('\\', '/');
        if (key == src ||
            src.endsWith('/$key') ||
            key.endsWith('/$src') ||
            key.split('/').last == baseName) {
          return entry.value;
        }
      }
    }
    if (_activeAppId.isNotEmpty && widget.gingacc.hasAppContext(_activeAppId)) {
      final appCtx = widget.gingacc.findAppContext(_activeAppId);
      final loaded = appCtx?.loadContentSync(src);
      if (loaded != null && loaded.isNotEmpty) {
        return loaded;
      }
    }
    for (final id in widget.gingacc.appContextIds) {
      final appCtx = widget.gingacc.findAppContext(id);
      final loaded = appCtx?.loadContentSync(src);
      if (loaded != null && loaded.isNotEmpty) {
        return loaded;
      }
    }
    return null;
  }

  Widget _buildActiveRenderer() {
    final src = _activeNodeSrc ?? '';
    final mime = (_activeNodeType ?? '').toLowerCase();
    final lowerSrc = src.toLowerCase();

    if (mime == 'application/x-ncl360' ||
        mime == 'application/x-ncl-360' ||
        lowerSrc.endsWith('.ncl360')) {
      return Scene360Widget(
        key: ValueKey('remote_player_ncl360_${_activeNodeId}_$_rendererEpoch'),
        src: src,
        mimeType: 'application/x-ncl360',
        gingacc: widget.gingacc,
        onHotspotViewChanged: (hotspotId, inView) {
          sendViewTransition(hotspotId, inView);
        },
      );
    }

    if (mime == 'text/html' ||
        mime == 'application/x-vlibras-gloss' ||
        lowerSrc.endsWith('.html') ||
        lowerSrc.endsWith('.htm')) {
      final virtualContent = _lookupVirtualContent(src);
      if (virtualContent != null && virtualContent.isNotEmpty) {
        return HtmlWidget.fromContent(
          virtualContent,
          key: _htmlKey,
          src: src,
          virtualFiles: widget.virtualFiles,
          gingacc: widget.gingacc,
        );
      }
      return HtmlWidget(
        key: _htmlKey,
        src: src,
        gingacc: widget.gingacc,
      );
    }

    if (mime == 'application/x-ginga-ncl' ||
        mime == 'application/x-ncl-ncl' ||
        lowerSrc.endsWith('.ncl')) {
      return NclWidget(
        key: ValueKey('remote_player_ncl_${_activeNodeId}_$_rendererEpoch'),
        src: src,
        gingacc: widget.gingacc,
      );
    }

    if (mime.startsWith('video/') || mime.startsWith('audio/')) {
      return AVWidget(
        key: ValueKey('remote_player_av_${_activeNodeId}_$_rendererEpoch'),
        src: src,
      );
    }

    if (mime.startsWith('image/')) {
      return ImageWidget(
        key: ValueKey('remote_player_img_${_activeNodeId}_$_rendererEpoch'),
        src: src,
      );
    }

    return TextWidget(
      key: ValueKey('remote_player_txt_${_activeNodeId}_$_rendererEpoch'),
      src: src,
      gingacc: widget.gingacc,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying || _activeNodeSrc == null || _activeNodeSrc!.isEmpty) {
      return Container(
        key: Key('remote_device_idle_${widget.deviceClass}'),
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.deviceClass == 'ncl-360-vr'
                    ? Icons.vrpano
                    : Icons.accessibility_new,
                color: const Color(0xFF9E9E9E),
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                'Remote Player: ${widget.deviceClass}',
                style: const TextStyle(
                  color: Color(0xFFD4D4D4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _client.handle != null
                    ? 'Connected (${_client.handle}) - waiting for main screen application to start'
                    : (_client.state == RemoteDeviceState.discovering
                        ? 'Discovering main screen via SSDP...'
                        : 'Connecting to main screen (${_client.state.name})...'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF858585), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return _buildActiveRenderer();
  }
}
