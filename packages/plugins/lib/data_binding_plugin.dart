import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/av.dart';
import 'package:nclui/base_widget.dart';
import 'package:nclui/nclui_plugins.dart';
import 'package:nclui/text.dart';

import 'data_binding_controller.dart';
import 'plugin_base.dart';

extension DataBindingRegionExtension on Region {
  String? get rows => rawAttributes['rows'];
  String? get columns => rawAttributes['columns'];
  String? get scroll => rawAttributes['scroll'];
  String? get wrap => rawAttributes['wrap'];
  String? get bufferSlots => rawAttributes['bufferSlots'];
}

extension DataBindingContextExtension on Context {
  String? get dataBinding => rawAttributes['data-binding'];
  String? get updatePolicy => rawAttributes['updatePolicy'];
}

class DataBindingMediaPlugin
    implements
        NclMediaPlugin,
        NclParserPlugin,
        NclTickPlugin,
        NclKeyPlugin,
        PluginBase {
  static final Expando<Map<String, DataBindingController>> _docControllers =
      Expando<Map<String, DataBindingController>>('dataBindingControllers');
  static final Expando<bool> _docPrepared =
      Expando<bool>('dataBindingPrepared');

  @override
  PluginType get type => PluginType.optional;

  @override
  String get targetTag => '*';

  @override
  (Head, Body)? parseDocument(XmlElement root, NclParser parser) => null;

  @override
  Element? parseTag(XmlElement node, NclParser parser) {
    _configureParserSchema(parser);
    return null;
  }

  static void _configureParserSchema(NclParser parser) {
    final schema = parser.schema;
    schema.addElementSyntax(
      'region',
      const ElementSyntax(
        possibleParents: ['region', 'regionBase'],
        attributes: {
          'id': attrId,
          'title': attrOptional,
          'left': attrOptional,
          'right': attrOptional,
          'top': attrOptional,
          'bottom': attrOptional,
          'height': attrOptional,
          'width': attrOptional,
          'zIndex': attrOptional,
          'rows': attrOptional,
          'columns': attrOptional,
          'scroll': attrOptional,
          'wrap': attrOptional,
          'bufferSlots': attrOptional,
        },
      ),
    );
    schema.addElementSyntax(
      'context',
      const ElementSyntax(
        possibleParents: ['body', 'context', 'switch'],
        attributes: {
          'id': attrId,
          'refer': attrOptIdref,
          'data-binding': attrOptional,
          'updatePolicy': attrOptional,
        },
      ),
    );
    schema.addElementSyntax(
      'media',
      const ElementSyntax(
        possibleParents: ['body', 'context', 'switch'],
        attributes: {
          'id': attrId,
          'src': attrOptional,
          'type': attrOptional,
          'descriptor': attrOptIdref,
          'refer': attrOptIdref,
          'instance': attrOptional,
          'updatePolicy': attrOptional,
          'rows': attrOptional,
          'columns': attrOptional,
          'scroll': attrOptional,
          'wrap': attrOptional,
          'bufferSlots': attrOptional,
        },
      ),
    );
  }

  static void ensureDocumentPrepared(NclDocument document) {
    if (_docPrepared[document] == true) return;
    _docPrepared[document] = true;

    final head = document.headChildren;
    final body = document.body;

    Descriptor? findDescriptor(String id) {
      Descriptor? search(Element parent) {
        if (parent is Descriptor && parent.id == id) return parent;
        for (final child in parent.children) {
          final res = search(child);
          if (res != null) return res;
        }
        return null;
      }

      for (final el in head) {
        final res = search(el);
        if (res != null) return res;
      }
      return null;
    }

    Region? findRegion(String id) {
      Region? search(Element parent) {
        if (parent is Region && parent.id == id) return parent;
        for (final child in parent.children) {
          final res = search(child);
          if (res != null) return res;
        }
        return null;
      }

      for (final el in head) {
        final res = search(el);
        if (res != null) return res;
      }
      return null;
    }

    double parsePercent(String val) {
      final trimmed = val.trim();
      if (trimmed.endsWith('%')) {
        final num =
            double.tryParse(trimmed.substring(0, trimmed.length - 1)) ?? 0.0;
        return num / 100.0;
      }
      return double.tryParse(trimmed) ?? 0.0;
    }

    (double, double, double, double) resolveBindingRegionRect(Region region) {
      final parentEl = region.parent;
      final widthVal = parsePercent(region.rawAttributes['width'] ?? '100%');
      final heightVal = parsePercent(region.rawAttributes['height'] ?? '100%');

      double leftVal = 0.0;
      if (region.rawAttributes['left'] != null) {
        leftVal = parsePercent(region.rawAttributes['left']!);
      } else if (region.rawAttributes['right'] != null) {
        leftVal = (1.0 - widthVal - parsePercent(region.rawAttributes['right']!))
            .clamp(0.0, 1.0);
      }

      double topVal = 0.0;
      if (region.rawAttributes['top'] != null) {
        topVal = parsePercent(region.rawAttributes['top']!);
      } else if (region.rawAttributes['bottom'] != null) {
        topVal = (1.0 - heightVal - parsePercent(region.rawAttributes['bottom']!))
            .clamp(0.0, 1.0);
      } else if (parentEl is Region &&
          (parentEl.rawAttributes.containsKey('rows') ||
              parentEl.rawAttributes['scroll'] == 'vertical')) {
        double cumulativeTop = 0.0;
        for (final sibling in parentEl.children.whereType<Region>()) {
          if (identical(sibling, region) ||
              (sibling.id != null && sibling.id == region.id)) {
            break;
          }
          cumulativeTop +=
              parsePercent(sibling.rawAttributes['height'] ?? '0%');
        }
        topVal = cumulativeTop.clamp(0.0, 1.0);
      }

      if (parentEl is Region) {
        final parentRect = resolveBindingRegionRect(parentEl);
        final leftAbs = parentRect.$1 + leftVal * parentRect.$3;
        final topAbs = parentRect.$2 + topVal * parentRect.$4;
        final widthAbs = widthVal * parentRect.$3;
        final heightAbs = heightVal * parentRect.$4;
        return (leftAbs, topAbs, widthAbs, heightAbs);
      }
      return (leftVal, topVal, widthVal, heightVal);
    }

    int resolveBindingRegionZIndex(Region region) {
      final zIndexStr =
          region.rawAttributes['zIndex'] ?? region.rawAttributes['zOrder'];
      if (zIndexStr != null) {
        return int.tryParse(zIndexStr) ?? 0;
      }
      final parentEl = region.parent;
      if (parentEl is Region) {
        return resolveBindingRegionZIndex(parentEl);
      }
      return 0;
    }

    void resolveDataBindingAttributes(Element el) {
      if (el is Media) {
        final descriptorId = el.rawAttributes['descriptor'];
        if (descriptorId != null) {
          final desc = findDescriptor(descriptorId);
          if (desc != null) {
            desc.rawAttributes.forEach((key, val) {
              if (key != 'id' && key != 'region') {
                el.rawAttributes.putIfAbsent(key, () => val);
              }
            });
            for (final dp in desc.descriptorParams) {
              final paramName = dp.name;
              final paramVal = dp.value;
              if (paramName != null && paramVal != null) {
                el.rawAttributes['descriptorParam.$paramName'] = paramVal;
                if (!el.children
                    .whereType<Property>()
                    .any((p) => p.name == paramName)) {
                  el.setPropertyValue(paramName, paramVal);
                }
              }
            }
          }
          final regionId = desc?.rawAttributes['region'];
          if (regionId != null) {
            final reg = findRegion(regionId);
            if (reg != null) {
              final rect = resolveBindingRegionRect(reg);
              el.rawAttributes['resolvedLeft'] =
                  '${(rect.$1 * 100).toStringAsFixed(2)}%';
              el.rawAttributes['resolvedTop'] =
                  '${(rect.$2 * 100).toStringAsFixed(2)}%';
              el.rawAttributes['resolvedWidth'] =
                  '${(rect.$3 * 100).toStringAsFixed(2)}%';
              el.rawAttributes['resolvedHeight'] =
                  '${(rect.$4 * 100).toStringAsFixed(2)}%';

              final zindex = resolveBindingRegionZIndex(reg);
              el.rawAttributes['resolvedZIndex'] = zindex.toString();

              el.rawAttributes['regionId'] = regionId;
              if (reg.rawAttributes['title'] != null) {
                el.rawAttributes['regionTitle'] = reg.rawAttributes['title']!;
              }
              if (reg.rawAttributes['left'] != null) {
                el.rawAttributes['regionLeft'] = reg.rawAttributes['left']!;
              }
              if (reg.rawAttributes['right'] != null) {
                el.rawAttributes['regionRight'] = reg.rawAttributes['right']!;
              }
              if (reg.rawAttributes['top'] != null) {
                el.rawAttributes['regionTop'] = reg.rawAttributes['top']!;
              }
              if (reg.rawAttributes['bottom'] != null) {
                el.rawAttributes['regionBottom'] = reg.rawAttributes['bottom']!;
              }
              if (reg.rawAttributes['width'] != null) {
                el.rawAttributes['regionWidth'] = reg.rawAttributes['width']!;
              }
              if (reg.rawAttributes['height'] != null) {
                el.rawAttributes['regionHeight'] = reg.rawAttributes['height']!;
              }
              if (reg.rawAttributes['zIndex'] != null) {
                el.rawAttributes['regionZIndex'] = reg.rawAttributes['zIndex']!;
              }
              if (reg.rawAttributes['rows'] != null) {
                el.rawAttributes['regionRows'] = reg.rawAttributes['rows']!;
              }
              if (reg.rawAttributes['columns'] != null) {
                el.rawAttributes['regionColumns'] =
                    reg.rawAttributes['columns']!;
              }
              if (reg.rawAttributes['scroll'] != null) {
                el.rawAttributes['regionScroll'] = reg.rawAttributes['scroll']!;
              }
              if (reg.rawAttributes['wrap'] != null) {
                el.rawAttributes['regionWrap'] = reg.rawAttributes['wrap']!;
              }
              if (reg.rawAttributes['bufferSlots'] != null) {
                el.rawAttributes['regionBufferSlots'] =
                    reg.rawAttributes['bufferSlots']!;
              }
              if (reg.parent is Region) {
                final parentReg = reg.parent as Region;
                if (parentReg.id != null) {
                  el.rawAttributes['parentRegionId'] = parentReg.id!;
                }
                if (parentReg.rawAttributes['rows'] != null) {
                  el.rawAttributes['parentRegionRows'] =
                      parentReg.rawAttributes['rows']!;
                }
                if (parentReg.rawAttributes['columns'] != null) {
                  el.rawAttributes['parentRegionColumns'] =
                      parentReg.rawAttributes['columns']!;
                }
                if (parentReg.rawAttributes['scroll'] != null) {
                  el.rawAttributes['parentRegionScroll'] =
                      parentReg.rawAttributes['scroll']!;
                }
                if (parentReg.rawAttributes['wrap'] != null) {
                  el.rawAttributes['parentRegionWrap'] =
                      parentReg.rawAttributes['wrap']!;
                }
                if (parentReg.rawAttributes['bufferSlots'] != null) {
                  el.rawAttributes['parentRegionBufferSlots'] =
                      parentReg.rawAttributes['bufferSlots']!;
                }
              }
            }
          }
        }
      }
      for (final child in el.children) {
        resolveDataBindingAttributes(child);
      }
    }

    bool stackedAny = false;

    void synthesizeBindingPorts(Context comp) {
      final existingPortComponents =
          comp.getPorts().map((p) => p.component).whereType<String>().toSet();
      final linkStartedIds = <String>{};
      for (final link in comp.getLinks()) {
        for (final bind in link.children.whereType<Bind>()) {
          final role = bind.rawAttributes['role'] ?? '';
          final compId = bind.rawAttributes['component'];
          if (role == 'start' && compId != null) {
            linkStartedIds.add(compId);
          }
        }
      }

      if (comp.rawAttributes.containsKey('data-binding')) {
        for (final media in comp.getMedias()) {
          final mediaId = media.id;
          if (mediaId == null ||
              existingPortComponents.contains(mediaId) ||
              linkStartedIds.contains(mediaId)) {
            continue;
          }
          final src = media.src ?? '';
          if (existingPortComponents.isEmpty || src.contains('{')) {
            final syntheticPort = Port(
              rawAttributes: {
                'id': '__db_port_$mediaId',
                'component': mediaId,
              },
            )..parent = comp;
            comp.children.add(syntheticPort);
            existingPortComponents.add(mediaId);
            if (comp.getMainState() == NclStateType.occurring &&
                media.getMainState() == NclStateType.sleeping) {
              document.scheduler.stackNclAction(
                media.getMainNclEvent(),
                NclActionType.start,
              );
              stackedAny = true;
            }
          }
        }
      }

      for (final childCtx in comp.getContexts()) {
        final ctxId = childCtx.id;
        if (ctxId != null &&
            !existingPortComponents.contains(ctxId) &&
            !linkStartedIds.contains(ctxId) &&
            childCtx.rawAttributes.containsKey('data-binding')) {
          final syntheticPort = Port(
            rawAttributes: {
              'id': '__db_port_$ctxId',
              'component': ctxId,
            },
          )..parent = comp;
          comp.children.add(syntheticPort);
          existingPortComponents.add(ctxId);
          if (comp.getMainState() == NclStateType.occurring &&
              childCtx.getMainState() == NclStateType.sleeping) {
            document.scheduler.stackNclAction(
              childCtx.getMainNclEvent(),
              NclActionType.start,
            );
            stackedAny = true;
          }
        }
        synthesizeBindingPorts(childCtx);
      }

      if (comp == body && existingPortComponents.isEmpty) {
        for (final media in comp.getMedias()) {
          if (media is Settings || media is UserSettings) continue;
          final mediaId = media.id;
          if (mediaId == null || existingPortComponents.contains(mediaId)) {
            continue;
          }
          final src = media.src ?? '';
          if (src.startsWith('sbtvd://') || src.contains('{')) {
            final syntheticPort = Port(
              rawAttributes: {
                'id': '__db_port_$mediaId',
                'component': mediaId,
              },
            )..parent = comp;
            comp.children.add(syntheticPort);
            existingPortComponents.add(mediaId);
            if (comp.getMainState() == NclStateType.occurring &&
                media.getMainState() == NclStateType.sleeping) {
              document.scheduler.stackNclAction(
                media.getMainNclEvent(),
                NclActionType.start,
              );
              stackedAny = true;
            }
          }
        }
      }
    }

    resolveDataBindingAttributes(body);
    synthesizeBindingPorts(body);
    if (stackedAny) {
      document.scheduler.tick(0);
    }
  }

  static Map<String, DataBindingController> controllersForDocument(
    NclDocument document,
  ) {
    ensureDocumentPrepared(document);
    var map = _docControllers[document];
    if (map == null) {
      map = <String, DataBindingController>{};
      _docControllers[document] = map;
    }
    return map;
  }

  static DataBindingController obtainController({
    required NclDocument document,
    Media? media,
    String? explicitContextId,
    Map<String, dynamic>? initialData,
  }) {
    ensureDocumentPrepared(document);
    final map = controllersForDocument(document);
    final parentCtx = (media?.parent is Context
            ? media!.parent as Context
            : null) ??
        (explicitContextId != null
            ? document.getContextById(explicitContextId)
            : null);
    final ctxId = explicitContextId ??
        parentCtx?.id ??
        document.currentKeyMaster ??
        media?.id ??
        'default_binding_ctx';

    final candidateMedias = <Media>[
      if (media != null) media,
      if (parentCtx != null)
        ...parentCtx.getMedias().where((m) => !identical(m, media)),
    ];

    final existing = map[ctxId];
    if (existing != null) {
      for (final m in candidateMedias) {
        existing.registerMedia(m);
      }
      if (initialData != null && initialData.isNotEmpty) {
        existing.updateData(initialData);
      }
      return existing;
    }

    final rawPolicy = parentCtx?.rawAttributes['updatePolicy'];
    final updateIntervalMs =
        NclParser.parseDurStr(rawPolicy?.trim().toLowerCase());

    final controller = DataBindingController(
      contextId: ctxId,
      updateIntervalMs: updateIntervalMs,
      initialData: initialData,
      medias: candidateMedias,
      document: document,
    );

    map[ctxId] = controller;
    return controller;
  }

  @override
  bool canHandle(String src, String? mimeType) {
    final trimmed = src.trim();
    if (trimmed.contains('{') && trimmed.contains('}')) {
      return true;
    }
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('.tvbind') || lower.endsWith('.nclbind')) {
      return true;
    }
    if (mimeType == 'application/x-ginga-binding' ||
        mimeType == 'application/x-ncl-binding') {
      return true;
    }
    return false;
  }

  @override
  void onTick(Duration elapsed, NclDocument document) {
    ensureDocumentPrepared(document);
    final map = _docControllers[document];
    if (map == null || map.isEmpty) return;
    for (final ctrl in map.values) {
      if (ctrl.updateIntervalMs != null && elapsed.inMilliseconds > 0) {
        ctrl.tickStream(document.virtualClock);
      }
    }
  }

  @override
  bool onKey(String keyCode, String keyType, NclDocument document) {
    if (keyType != 'press') return false;
    ensureDocumentPrepared(document);

    final keyMaster = document.currentKeyMaster;
    final map = controllersForDocument(document);

    DataBindingController? targetController;
    Context? targetContext;

    if (keyMaster != null && keyMaster.isNotEmpty) {
      final node = document.getNodeById(keyMaster);
      if (node is Context &&
          (node.rawAttributes.containsKey('data-binding') ||
              node.getMedias().any((m) => (m.src ?? '').contains('{')))) {
        targetContext = node;
        final firstMedia = node.getMedias().firstOrNull;
        targetController = obtainController(
          document: document,
          media: firstMedia,
          explicitContextId: node.id,
        );
      } else if (node is Media && node.parent is Context) {
        final parentCtx = node.parent as Context;
        if (parentCtx.rawAttributes.containsKey('data-binding') ||
            parentCtx.getMedias().any((m) => (m.src ?? '').contains('{'))) {
          targetContext = parentCtx;
          targetController = obtainController(
            document: document,
            media: node,
            explicitContextId: parentCtx.id,
          );
        }
      } else if (map.containsKey(keyMaster)) {
        targetController = map[keyMaster];
        final ctxNode = document.getContextById(keyMaster);
        if (ctxNode != null) targetContext = ctxNode;
      }
      if (targetController == null) {
        return false;
      }
    }

    if (targetController == null && map.isNotEmpty) {
      targetController = map.values.first;
      targetContext = document.getContextById(targetController.contextId);
    }

    if (targetController == null) {
      for (final ctx in document.body.getContexts()) {
        if (ctx.rawAttributes.containsKey('data-binding') ||
            ctx.getMedias().any((m) => (m.src ?? '').contains('{'))) {
          targetContext = ctx;
          targetController = obtainController(
            document: document,
            media: ctx.getMedias().firstOrNull,
            explicitContextId: ctx.id,
          );
          break;
        }
      }
    }

    if (targetController == null) return false;

    final isSelectionKey =
        keyCode == 'ENTER' || keyCode == 'OK' || keyCode == 'SELECT';

    void syncContextDynamicMedia({required bool includeAvMedia}) {
      if (targetContext == null || targetController == null) return;
      for (final media in targetContext.getMedias()) {
        final isAv = media.mimeType.startsWith('video/') ||
            media.mimeType.startsWith('audio/');
        if (isAv && !includeAvMedia) continue;
        final rawSrc = media.rawAttributes['src'] ?? '';
        if (BindingExpression.isDynamicExpression(rawSrc)) {
          try {
            final expr = BindingExpression.parse(rawSrc);
            final resolved = expr.evaluateAsString(
              targetController.data,
              row: targetController.focusedRow,
              column: targetController.focusedCol,
            );
            if (resolved.isNotEmpty) {
              media.rawAttributes['resolvedSrc'] = resolved;
              media.setPropertyValue('resolvedSrc', resolved);
            }
          } catch (_) {}
        }
      }
    }

    if (isSelectionKey) {
      syncContextDynamicMedia(includeAvMedia: true);
    }

    final handled = targetController.handleKey(keyCode);
    if (!handled) return false;

    syncContextDynamicMedia(includeAvMedia: isSelectionKey);

    if (targetContext != null && isSelectionKey) {
      for (final media in targetContext.getMedias()) {
        if (media.id != null &&
            media.getMainState() == NclStateType.occurring) {
          document.triggerSelection(media.id!, 'ENTER');
        }
      }
    }

    return true;
  }

  @override
  Widget buildWidget({
    Key? key,
    required String src,
    String? mimeType,
    Media? media,
    NclDocument? document,
    FocusNode? focusNode,
  }) {
    return DataBindingWidget(
      key: key,
      src: src,
      mimeType: mimeType,
      media: media,
      document: document,
      focusNode: focusNode,
    );
  }
}

class DataBindingWidget extends BaseWidget {
  final String? mimeType;
  final FocusNode? focusNode;

  const DataBindingWidget({
    super.key,
    required super.src,
    this.mimeType,
    super.media,
    super.document,
    this.focusNode,
  });

  @override
  State<DataBindingWidget> createState() => _DataBindingWidgetState();
}

class _DataBindingWidgetState extends MediaState<DataBindingWidget> {
  DataBindingController? _controller;
  BindingExpression? _expression;
  late final FocusNode _internalFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _initControllerAndData();
    parseProperties(widget.media);
  }

  void _initControllerAndData() {
    final rawSrc = widget.media?.rawAttributes['src'] ?? widget.src;
    if (BindingExpression.isDynamicExpression(rawSrc)) {
      try {
        _expression = BindingExpression.parse(rawSrc);
      } catch (_) {}
    }

    if (widget.document != null) {
      _controller = DataBindingMediaPlugin.obtainController(
        document: widget.document!,
        media: widget.media,
      );
    } else {
      final rows = int.tryParse(
            widget.media?.rawAttributes['regionRows'] ??
                widget.media?.rawAttributes['rows'] ??
                '',
          ) ??
          3;
      final cols = int.tryParse(
            widget.media?.rawAttributes['regionColumns'] ??
                widget.media?.rawAttributes['columns'] ??
                '',
          ) ??
          4;
      final scroll = ScrollDirectionMode.fromString(
        widget.media?.rawAttributes['regionScroll'] ??
            widget.media?.rawAttributes['scroll'] ??
            'both',
      );
      _controller = DataBindingController(
        contextId: widget.media?.id ?? 'standalone_ctx',
        visibleRows: rows,
        visibleColumns: cols,
        scrollMode: scroll,
        medias: widget.media != null ? [widget.media!] : null,
      );
    }

    _controller?.addListener(_onControllerUpdated);
    _loadExternalDataIfNeeded();
  }

  Future<void> _loadExternalDataIfNeeded() async {
    final ctrl = _controller;
    if (ctrl == null ||
        ctrl.hasLoadedExternalData ||
        ctrl.isLoadingExternalData) {
      return;
    }
    final parentCtx =
        widget.media?.parent is Context ? widget.media!.parent as Context : null;
    final dataBindingPath = parentCtx?.rawAttributes['data-binding'] ??
        widget.media?.rawAttributes['data-binding'];
    if (dataBindingPath == null || dataBindingPath.isEmpty) return;

    ctrl.markExternalDataLoading(true);
    try {
      final content = await widget.privateBase.loadContent(dataBindingPath);
      if (content != null && content.trim().isNotEmpty) {
        ctrl.executeLua(content);
        ctrl.markExternalDataLoaded();
      } else {
        ctrl.markExternalDataLoading(false);
      }
    } catch (_) {
      ctrl.markExternalDataLoading(false);
    }
  }

  void _onControllerUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant DataBindingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src || oldWidget.media != widget.media) {
      _controller?.removeListener(_onControllerUpdated);
      _initControllerAndData();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdated);
    _internalFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.document != null) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    String? mapped;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      mapped = 'CURSOR_RIGHT';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      mapped = 'CURSOR_LEFT';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      mapped = 'CURSOR_DOWN';
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      mapped = 'CURSOR_UP';
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select) {
      mapped = 'ENTER';
    }
    if (mapped != null) {
      _controller?.handleKey(mapped);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _resolveBoundVideoSrc(DataBindingController ctrl) {
    final propResolved = widget.media
        ?.getProperties()
        .where((p) => p.name == 'resolvedSrc')
        .map((p) => p.value)
        .whereType<String>()
        .firstOrNull;
    final attrResolved = widget.media?.rawAttributes['resolvedSrc'];
    if (propResolved != null && propResolved.isNotEmpty) {
      return propResolved;
    }
    if (attrResolved != null && attrResolved.isNotEmpty) {
      return attrResolved;
    }
    if (ctrl.data.isNotEmpty && _expression != null) {
      final evaluated = _expression!.evaluateAsString(
        ctrl.data,
        row: ctrl.focusedRow,
        column: ctrl.focusedCol,
        fallback: '',
      );
      if (evaluated.isNotEmpty) {
        widget.media?.rawAttributes['resolvedSrc'] = evaluated;
        widget.media?.setPropertyValue('resolvedSrc', evaluated);
        return evaluated;
      }
    }
    return '';
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return const SizedBox.shrink();
    }

    final mime = widget.media?.mimeType ?? widget.mimeType ?? '';
    if (mime.startsWith('video/')) {
      final resolvedSrc = _resolveBoundVideoSrc(ctrl);
      if (resolvedSrc.isEmpty) {
        return const ColoredBox(color: Colors.black);
      }
      return ColoredBox(
        color: Colors.black,
        child: AVWidget(
          key: ValueKey<String>('bound_av_widget_$resolvedSrc'),
          src: resolvedSrc,
          document: widget.document,
        ),
      );
    }

    final effectiveExpr =
        _expression ?? BindingExpression.parse('{items[row][column]}');
    final content = _buildExpressionRegionView(ctrl, effectiveExpr);

    if (widget.document != null && widget.focusNode == null) {
      return content;
    }

    return Focus(
      focusNode: _effectiveFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: content,
    );
  }

  Widget _buildExpressionRegionView(
    DataBindingController ctrl,
    BindingExpression expr,
  ) {
    final explicitRegRows =
        int.tryParse(widget.media?.rawAttributes['regionRows'] ?? '');
    final parentRegRows =
        int.tryParse(widget.media?.rawAttributes['parentRegionRows'] ?? '');

    if (expr.usesRow && !expr.usesColumn) {
      if (explicitRegRows == null && parentRegRows != null) {
        return _buildSingleRowHeader(ctrl, expr);
      }
      final regRows = explicitRegRows ?? ctrl.visibleRows;
      return _buildVerticalRail(ctrl, expr, regRows);
    }

    if (!expr.usesRow && expr.usesColumn) {
      final regCols = int.tryParse(
            widget.media?.rawAttributes['regionColumns'] ?? '',
          ) ??
          ctrl.visibleColumns;
      return _buildHorizontalRail(
        ctrl,
        expr,
        regCols,
        railRowIndex: ctrl.railRowIndexForMedia(widget.media, expr),
      );
    }

    final regRows = explicitRegRows ?? parentRegRows ?? ctrl.visibleRows;
    final regCols = int.tryParse(
          widget.media?.rawAttributes['regionColumns'] ??
              widget.media?.rawAttributes['parentRegionColumns'] ??
              '',
        ) ??
        ctrl.visibleColumns;
    return _build2DMatrixSlotView(ctrl, expr, regRows, regCols);
  }

  BoxDecoration? _buildCellDecoration({required bool isFocused}) {
    final cellBg = background != Colors.transparent ? background : null;
    final hasFocusBorder = isFocused &&
        focusBorderColor != Colors.transparent &&
        focusBorderWidth > 0;
    final cellBorder = hasFocusBorder
        ? Border.all(
            color: focusBorderColor,
            width: focusBorderWidth.toDouble(),
          )
        : null;
    if (cellBg == null && cellBorder == null) {
      return null;
    }
    return BoxDecoration(
      color: cellBg,
      border: cellBorder,
    );
  }

  Widget _buildSingleRowHeader(
    DataBindingController ctrl,
    BindingExpression expr,
  ) {
    final label = expr.evaluateAsString(
      ctrl.data,
      row: ctrl.focusedRow,
      column: ctrl.focusedCol,
    );

    return Container(
      alignment: Alignment.centerLeft,
      decoration: _buildCellDecoration(isFocused: false),
      child: TextWidget(
        src: label,
        media: widget.media,
        document: widget.document,
        embedded: true,
        maxLines: 1,
      ),
    );
  }

  Widget _buildVerticalRail(
    DataBindingController ctrl,
    BindingExpression expr,
    int visibleCount,
  ) {
    final startRow = ctrl.viewportRowStart;
    final endRow = math.min(ctrl.totalRows, startRow + visibleCount);
    final items = <Widget>[];

    for (int r = startRow; r < endRow; r++) {
      final isFocusedRow = (r == ctrl.focusedRow);
      final label = expr.evaluateAsString(
        ctrl.data,
        row: r,
        column: ctrl.focusedCol,
      );
      items.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              while (ctrl.focusedRow < r) {
                ctrl.handleKey('CURSOR_DOWN');
              }
              while (ctrl.focusedRow > r) {
                ctrl.handleKey('CURSOR_UP');
              }
            },
            child: Container(
              alignment: Alignment.centerLeft,
              decoration: _buildCellDecoration(isFocused: isFocusedRow),
              child: TextWidget(
                src: label,
                media: widget.media,
                document: widget.document,
                embedded: true,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
    );
  }

  Widget _buildHorizontalRail(
    DataBindingController ctrl,
    BindingExpression expr,
    int visibleCount, {
    int? railRowIndex,
  }) {
    final effectiveRow = railRowIndex ?? ctrl.focusedRow;
    final startCol = railRowIndex != null
        ? ctrl.rowColOffsetForRow(railRowIndex)
        : ctrl.viewportColStart;
    final maxCols = ctrl.totalColumnsForRow(effectiveRow);
    final endCol = math.min(maxCols, startCol + visibleCount);
    final isActiveRow =
        railRowIndex == null || (ctrl.focusedRow == railRowIndex);
    final cells = <Widget>[];

    for (int c = startCol; c < endCol; c++) {
      final isFocused = isActiveRow && (c == ctrl.focusedCol);
      final label = expr.evaluateAsString(
        ctrl.data,
        row: effectiveRow,
        column: c,
      );
      cells.add(
        Expanded(
          child: Container(
            alignment: Alignment.center,
            decoration: _buildCellDecoration(isFocused: isFocused),
            child: TextWidget(
              src: label,
              media: widget.media,
              document: widget.document,
              embedded: true,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cells,
    );
  }

  Widget _build2DMatrixSlotView(
    DataBindingController ctrl,
    BindingExpression expr,
    int visibleRows,
    int visibleCols,
  ) {
    final startRow = ctrl.viewportRowStart;
    final endRow = math.min(ctrl.totalRows, startRow + visibleRows);
    final rowWidgets = <Widget>[];

    for (int r = startRow; r < endRow; r++) {
      final startCol = ctrl.hasIndependentRowHorizontalScroll
          ? ctrl.rowColOffsetForRow(r)
          : ctrl.viewportColStart;
      final maxCols = ctrl.totalColumnsForRow(r);
      final endCol = math.min(maxCols, startCol + visibleCols);
      final colWidgets = <Widget>[];

      for (int c = startCol; c < endCol; c++) {
        final isFocused = (r == ctrl.focusedRow && c == ctrl.focusedCol);
        final slot = ctrl.slotPool.acquireSlot(r, c);
        final label = expr.evaluateAsString(
          ctrl.data,
          row: r,
          column: c,
        );
        slot.bind(
          logicalRow: r,
          logicalCol: c,
        );

        colWidgets.add(
          Expanded(
            key: ValueKey<String>('slot_pool_${slot.poolSlotId}'),
            child: GestureDetector(
              onTap: () {
                while (ctrl.focusedRow < r) {
                  ctrl.handleKey('CURSOR_DOWN');
                }
                while (ctrl.focusedRow > r) {
                  ctrl.handleKey('CURSOR_UP');
                }
                while (ctrl.focusedCol < c) {
                  ctrl.handleKey('CURSOR_RIGHT');
                }
                while (ctrl.focusedCol > c) {
                  ctrl.handleKey('CURSOR_LEFT');
                }
                if (widget.document != null) {
                  widget.document!.handleKey('ENTER');
                } else {
                  ctrl.handleKey('ENTER');
                }
              },
              child: Container(
                alignment: Alignment.center,
                decoration: _buildCellDecoration(isFocused: isFocused),
                child: TextWidget(
                  src: label,
                  media: widget.media,
                  document: widget.document,
                  embedded: true,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        );
      }

      rowWidgets.add(
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: colWidgets,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rowWidgets,
    );
  }
}
