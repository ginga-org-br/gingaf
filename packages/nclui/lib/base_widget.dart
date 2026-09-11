import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart';

import 'ncl.dart';

export 'package:gingacc/gingacc.dart';

abstract class BaseWidget extends StatefulWidget {
  final String src;
  final Media? media;
  final NclDocument? document;
  final GingaCC? gingacc;

  const BaseWidget({
    super.key,
    required this.src,
    this.media,
    this.document,
    this.gingacc,
  });
}

abstract class MediaState<T extends BaseWidget> extends State<T> {
  Color background = Colors.transparent;
  Rect rect = Rect.zero;
  bool debug = false;
  bool visible = true;
  int alpha = 255;
  int zindex = 0;
  int zorder = 0;
  int focusIndex = 0;
  Color focusBorderColor = Colors.transparent;
  int focusBorderWidth = 0;
  int focusBorderTransparency = 0;
  Color selBorderColor = Colors.transparent;
  String? id;
  String leftStr = '0%';
  String topStr = '0%';
  String widthStr = '100%';
  String heightStr = '100%';
  bool isPositioned = false;
  double soundLevel = 1.0;

  Media? _media;
  NclDocument? _document;

  Media? get media => _media ?? widget.media;
  NclDocument? get document => _document ?? widget.document;

  void setMedia(Media? newMedia, [NclDocument? newDocument]) {
    _media = newMedia;
    if (newDocument != null) {
      _document = newDocument;
    }
    parseProperties(media);
    if (mounted) {
      setState(() {});
    }
  }

  void clearMedia() {
    _media = null;
    _document = null;
    isPositioned = false;
    leftStr = '0%';
    topStr = '0%';
    widthStr = '100%';
    heightStr = '100%';
    rect = Rect.zero;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    parseProperties(media);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    parseProperties(media);
  }

  void parseProperties([Media? targetMedia]) {
    final m = targetMedia ?? media;
    if (m == null) return;
    isPositioned = true;
    id = m.id;
    String? backgroundVal;
    String? boundsVal;
    String? leftVal;
    String? topVal;
    String? widthVal;
    String? heightVal;
    String? zIndexVal;
    for (var prop in m.getProperties()) {
      if (prop.name == 'background') {
        backgroundVal = prop.value;
      } else if (prop.name == 'bounds') {
        boundsVal = prop.value;
      } else if (prop.name == 'left') {
        leftVal = prop.value;
      } else if (prop.name == 'top') {
        topVal = prop.value;
      } else if (prop.name == 'width') {
        widthVal = prop.value;
      } else if (prop.name == 'height') {
        heightVal = prop.value;
      } else if (prop.name == 'zIndex' || prop.name == 'zOrder') {
        zIndexVal = prop.value;
      } else if (prop.name == 'soundLevel') {
        final slStr = prop.value?.trim() ?? '';
        if (slStr.endsWith('%')) {
          final pct = double.tryParse(slStr.substring(0, slStr.length - 1));
          if (pct != null) soundLevel = (pct / 100.0).clamp(0.0, 1.0);
        } else {
          final val = double.tryParse(slStr);
          if (val != null) {
            soundLevel = val.clamp(0.0, 1.0);
          }
        }
      }
    }

    if (boundsVal != null) {
      final boundsParts = boundsVal.split(',');
      if (boundsParts.length == 4) {
        leftStr = boundsParts[0].trim();
        topStr = boundsParts[1].trim();
        widthStr = boundsParts[2].trim();
        heightStr = boundsParts[3].trim();
      }
    } else {
      leftStr = m.rawAttributes['resolvedLeft'] ?? '0%';
      topStr = m.rawAttributes['resolvedTop'] ?? '0%';
      widthStr = m.rawAttributes['resolvedWidth'] ?? '100%';
      heightStr = m.rawAttributes['resolvedHeight'] ?? '100%';
    }
    if (leftVal != null) leftStr = leftVal;
    if (topVal != null) topStr = topVal;
    if (widthVal != null) widthStr = widthVal;
    if (heightVal != null) heightStr = heightVal;
    if (zIndexVal != null) {
      zindex = int.tryParse(zIndexVal) ?? 0;
    } else if (m.rawAttributes.containsKey('resolvedZIndex')) {
      zindex = int.tryParse(m.rawAttributes['resolvedZIndex']!) ?? 0;
    } else {
      zindex = 0;
    }
    final visibleStr = m.rawAttributes['visible'] ?? 'true';
    visible = visibleStr.toLowerCase() == 'true';
    background = _parseColor(backgroundVal);
    focusBorderColor = _parseColor(m.rawAttributes['focusBorderColor']);
    selBorderColor = _parseColor(m.rawAttributes['selBorderColor']);
  }

  void syncProperties() {
    if (mounted) {
      setState(() {
        parseProperties(media);
      });
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.transparent;
    if (colorStr.startsWith('#')) {
      final hex = colorStr.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    switch (colorStr.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      default:
        return Colors.transparent;
    }
  }

  double _resolveDim(String val, double parentDim) {
    final trimmed = val.trim();
    if (trimmed.endsWith('%')) {
      final pct =
          double.tryParse(trimmed.substring(0, trimmed.length - 1)) ?? 0.0;
      return parentDim * pct / 100.0;
    }
    return double.tryParse(trimmed) ?? 0.0;
  }

  String get playerKey => id ?? '';

  @override
  Widget build(BuildContext context) {
    final parentBounds = NclWidget.maybeOf(context)?.bounds;
    final size = MediaQuery.maybeOf(context)?.size;
    final planeWidth = parentBounds?.width ??
        size?.width ??
        (document?.config.graphsPlaneBounds.width ?? 720.0);
    final planeHeight = parentBounds?.height ??
        size?.height ??
        (document?.config.graphsPlaneBounds.height ?? 480.0);

    double left, top, width, height;
    left = _resolveDim(leftStr, planeWidth);
    top = _resolveDim(topStr, planeHeight);
    width = _resolveDim(widthStr, planeWidth);
    height = _resolveDim(heightStr, planeHeight);
    rect = Rect.fromLTWH(left, top, width, height);

    final isFocused = document?.currentFocusNodeId != null &&
        document?.currentFocusNodeId == id;
    final activeBorderColor = isFocused
        ? (focusBorderColor != Colors.transparent
            ? focusBorderColor
            : Colors.yellowAccent)
        : Colors.transparent;

    Widget content = Visibility(
      visible: visible,
      child: Opacity(
        opacity: alpha / 255.0,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: selBorderColor != Colors.transparent
                ? Border.all(color: selBorderColor, width: 3.0)
                : (activeBorderColor != Colors.transparent
                    ? Border.all(color: activeBorderColor, width: 2.0)
                    : null),
          ),
          child: buildWidgetContent(context),
        ),
      ),
    );

    final desc = (document != null && media != null)
        ? document!.getDescriptorForMedia(media!)
        : null;
    final hasFocusIndex = desc?.focusIndex != null;
    final hasSelectionLink = id != null &&
        document != null &&
        document!.scheduler.getLinksForComponent(id!).any((l) => l.children
            .whereType<Bind>()
            .any((b) =>
                (b.role == 'onSelection' || b.role == 'onSelect') &&
                b.component == id));
    final canReceiveTap = hasFocusIndex || hasSelectionLink;

    if (id != null && document != null && canReceiveTap) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            document?.setFocus(id!);
            document?.handleSelection(id);
          },
          child: content,
        ),
      );
    }
    if (!isPositioned || rect == Rect.zero) {
      return content;
    }
    return Positioned.fromRect(
      rect: rect,
      child: content,
    );
  }

  Widget buildWidgetContent(BuildContext context);
}
