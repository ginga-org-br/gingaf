import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:ncldoc/ncl_document.dart' hide State;

import '../ginga.dart';
import '../main_av.dart';
import '../ginga_content.dart';
import 'widgets/ncl_media_widget.dart';

export 'widgets/av.dart';
export 'widgets/html.dart';
export 'widgets/image.dart';
export 'widgets/lua.dart';
export 'widgets/ncl_media_widget.dart';
export 'widgets/ssml.dart';
export 'widgets/text.dart';

final _logger = Logger('ginga-ncl');

class NCLAppExitNotification extends Notification {}

class NCLApp extends MediaWidget {
  final MainAVController? mainAVController;
  final GingaConfig config;

  NCLApp({
    super.key,
    required String src,
    super.media,
    this.mainAVController,
    GingaConfig? config,
  })  : config = config ?? const GingaConfig(),
        super(src: src);

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
      final resolvedUri = sbtvdUri.startsWith('sbtvd://')
          ? (_initialMainAvUri ?? sbtvdUri)
          : sbtvdUri;
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
    await Future.microtask(() {});
    try {
      if (mounted) {
        setState(() {});
      }

      final ContentLoader activeLoader;
      if (widget.config.contentLoader is GingaContentLoader) {
        activeLoader = (widget.config.contentLoader as GingaContentLoader)
          ..setBuildContext(context);
      } else if (widget.config.contentLoader == null ||
          widget.config.contentLoader is FileContentLoader) {
        activeLoader = GingaContentLoader()..setBuildContext(context);
      } else {
        activeLoader = widget.config.contentLoader;
      }

      final uriString = widget.uri.toString();
      final docUri = uriString.trim().startsWith('<')
          ? Uri.parse('file://main.ncl')
          : widget.uri;
      final String nclData;
      if (uriString.trim().startsWith('<')) {
        nclData = uriString;
      } else {
        nclData = await activeLoader.load(docUri) ?? '';
      }
      if (!mounted) return;

      final usersDataSrc = widget.config.usersDataSrc;
      String? effectiveUserData;
      if (usersDataSrc != null) {
        final str = usersDataSrc.trim();
        if (str.startsWith('[') || str.startsWith('{')) {
          effectiveUserData = str;
        } else {
          final content = await activeLoader.load(Uri.parse(str));
          if (!mounted) return;
          if (content == null) {
            throw Exception('USERS_DATA file does not exist: $usersDataSrc');
          }
          effectiveUserData = content;
        }
      }
      if (!mounted) return;
      final doc = NCLDocument.fromContent(
        nclData,
        docUri: docUri,
        usersDataJson: effectiveUserData,
        contentLoader: activeLoader,
      );

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
          _ticker?.cancel();
          _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (!mounted || _ticker == null) {
              timer.cancel();
              return;
            }
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
    _ticker = null;
    final doc = nclDocument;
    nclDocument = null;
    try {
      doc?.stop();
    } catch (e) {
      _logger.warning("Error stopping doc in dispose: $e");
    }
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
