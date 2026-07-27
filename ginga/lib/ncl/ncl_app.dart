import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:ncldoc/ncl_document.dart' hide State;

import '../main_av.dart';
import '../ginga.dart';
import 'widgets/ncl_media_widget.dart';

export 'widgets/av.dart';
export 'widgets/image.dart';
export 'widgets/lua.dart';
export 'widgets/ncl_media_widget.dart';
export 'widgets/ssml.dart';
export 'widgets/text.dart';
export 'widgets/html.dart';

final _logger = Logger('ginga-ncl');

class NCLAppExitNotification extends Notification {}

class NCLApp extends MediaWidget {
  final MainAVController? mainAVController;
  final String? usersDataJson;
  final GingaConfig? config;

  const NCLApp({
    super.key,
    required super.uri,
    super.media,
    this.mainAVController,
    this.usersDataJson,
    this.config,
  });

  @override
  State<NCLApp> createState() => NCLAppState();
}

class NCLAppState extends MediaState<NCLApp> {
  final Map<String, GlobalKey<MediaState>> _mediaStateKeys = {};
  final Map<String, Widget> _cachedWidgets = {};
  NCLDocument? nclDocument;
  Timer? _ticker;
  String errorMsg = "";
  bool _loading = false;
  String? _initialMainAvUri;
  final Map<String, String> persistentVars = {};

  bool _syncActiveMedia(List<Media> activeMedia) {
    bool changed = false;
    final currentIds = activeMedia.map((m) => m.id ?? '').toSet();

    String? sbtvdUri;
    for (var media in activeMedia) {
      if (media.uri.startsWith('sbtvd://')) {
        sbtvdUri = media.uri;
      }
    }
    if (sbtvdUri != null) {
      final resolvedUri = sbtvdUri.startsWith('sbtvd://') ? (_initialMainAvUri ?? sbtvdUri) : sbtvdUri;
      widget.mainAVController?.setMainAvUri(resolvedUri);
    } else {
      if (widget.mainAVController != null &&
          widget.mainAVController!.uri != _initialMainAvUri) {
        widget.mainAVController!.setMainAvUri(_initialMainAvUri);
      }
    }

    final toRemove =
        _cachedWidgets.keys.where((id) => !currentIds.contains(id)).toList();
    if (toRemove.isNotEmpty) changed = true;
    for (var id in toRemove) {
      _cachedWidgets.remove(id);
      _mediaStateKeys.remove(id);
    }

    for (var media in activeMedia) {
      final id = media.id ?? '';
      if (!_cachedWidgets.containsKey(id)) {
        final key = GlobalKey<MediaState>();
        final mediaWidget = WidgetFactory.createMediaWidget(
          key: key,
          media: media,
          mainAVController: widget.mainAVController,
        );
        if (mediaWidget != null) {
          _mediaStateKeys[id] = key;
          _cachedWidgets[id] = mediaWidget;
          changed = true;
        }
      }
    }
    return changed;
  }

  @override
  void initState() {
    super.initState();
    _initialMainAvUri = widget.mainAVController?.uri;
    _logger.info("Starting NCL application: ${widget.uri}");
    _startApplication();
  }

  Future<void> _startApplication() async {
    if (_loading) return;
    _loading = true;
    try {
      if (mounted) {
        setState(() {});
      }

      String nclData = await loadContent(widget.uri);

      String localPath = widget.uri;
      if (!kIsWeb && !widget.uri.startsWith('http://') && !widget.uri.startsWith('https://')) {
        final file = File(widget.uri);
        if (file.existsSync()) {
          localPath = file.absolute.path;
        } else {
          final fileName = widget.uri.contains('/') ? widget.uri.substring(widget.uri.lastIndexOf('/') + 1) : widget.uri;
          final localFile = File(fileName);
          if (localFile.existsSync()) {
            localPath = localFile.absolute.path;
          }
        }
      }
      final uri = widget.uri.startsWith('http')
          ? Uri.parse(widget.uri)
          : (kIsWeb ? Uri.parse(widget.uri) : Uri.file(localPath));
      NCLDocument.uriResolver = GingaConfig.uriResolver;
      var effectiveUserData = widget.config?.usersDataJson ?? widget.usersDataJson;
      if (effectiveUserData != null) {
        String? content;
        try {
          content = await DefaultAssetBundle.of(context).loadString(effectiveUserData.trim());
        } catch (_) {}
        if (content == null) {
          final parsedUri = Uri.tryParse(effectiveUserData.trim());
          content = parsedUri != null ? GingaConfig.uriResolver(parsedUri) : null;
        }
        if (content == null) {
          throw Exception('USERS_DATA file does not exist: $effectiveUserData');
        }
        effectiveUserData = content;
      }
      final doc = NCLDocument.fromXML(nclData, baseURI: uri, usersDataJson: effectiveUserData);

      nclDocument = doc;
      doc.start();

      _syncActiveMedia(doc.getActiveMedia());

      if (mounted) {
        setState(() {
          errorMsg = "";
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          DateTime lastTick = DateTime.now();
          _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (mounted) {
              final now = DateTime.now();
              final deltaMs = now.difference(lastTick).inMilliseconds;
              lastTick = now;
              final changedMedia = nclDocument?.tick(deltaMs) ?? <Media>{};

              if (nclDocument != null) {
                for (var media in changedMedia) {
                  _mediaStateKeys[media.id ?? '']
                      ?.currentState
                      ?.syncProperties();
                }

                final currentActiveMedia = nclDocument!.getActiveMedia();
                if (_syncActiveMedia(currentActiveMedia)) {
                  if (mounted) {
                    setState(() {});
                  }
                }

                if (!nclDocument!.isPlaying) {
                  _ticker?.cancel();
                  _ticker = null;
                  nclDocument = null;
                  if (mounted) {
                    setState(() {});
                  }
                  NCLAppExitNotification().dispatch(context);
                }
              }
            }
          });
        });
      }
    } catch (e, stacktrace) {
      _logger.severe("Error: $e\n$stacktrace");
      if (mounted) {
        setState(() {
          errorMsg = "Error: $e";
        });
      }
    } finally {
      _loading = false;
    }
  }

  void tick(int ms) {
    if (nclDocument != null) {
      final changedMedia = nclDocument!.tick(ms);
      for (var media in changedMedia) {
        _mediaStateKeys[media.id ?? '']?.currentState?.syncProperties();
      }
      _syncActiveMedia(nclDocument!.getActiveMedia());
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _logger.info("Stopping NCL application: ${widget.uri}");
    _ticker?.cancel();
    final doc = nclDocument;
    nclDocument = null;
    doc?.stop();
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (nclDocument == null && _cachedWidgets.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: errorMsg.isNotEmpty
              ? Text(errorMsg, style: const TextStyle(color: Colors.red))
              : const CircularProgressIndicator(),
        ),
      );
    }

    final activeMedia = List<Media>.from(nclDocument?.getActiveMedia() ?? []);
    activeMedia.sort((a, b) {
      int getZIndex(Media media) {
        final zIndexProp = media
            .getProperties()
            .where((p) => p.name == 'zIndex' || p.name == 'zOrder')
            .firstOrNull;
        if (zIndexProp != null && zIndexProp.value != null) {
          return int.tryParse(zIndexProp.value!) ?? 0;
        }
        final resolvedZ = media.rawAttributes['resolvedZIndex'];
        if (resolvedZ != null) {
          return int.tryParse(resolvedZ) ?? 0;
        }
        return 0;
      }

      return getZIndex(a).compareTo(getZIndex(b));
    });

    final List<Widget> children = [];
    for (var media in activeMedia) {
      final widget = _cachedWidgets[media.id ?? ''];
      if (widget != null) {
        children.add(widget);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        key: const Key('ncl_app_stack'),
        fit: StackFit.expand,
        children: children,
      ),
    );
  }
}
