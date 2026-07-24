import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ncldoc/ncl_document.dart' hide State;

import '../../web_utils_stub.dart'
    if (dart.library.html) '../../web_utils_web.dart';
import '../ncl_app.dart';
import '../../main_av.dart';

abstract class MediaWidget extends StatefulWidget {
  final String uri;
  final Media? media;

  const MediaWidget({
    super.key,
    required this.uri,
    this.media,
  });
}

abstract class MediaState<T extends MediaWidget> extends State<T> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    parseProperties(widget.media);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    parseProperties(widget.media);
  }

  void parseProperties(Media? media) {
    if (media == null) return;
    isPositioned = true;
    id = media.id;
    String? backgroundVal;
    String? boundsVal;
    String? leftVal;
    String? topVal;
    String? widthVal;
    String? heightVal;
    String? zIndexVal;
    for (var prop in media.getProperties()) {
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
      leftStr = media.rawAttributes['resolvedLeft'] ?? '0%';
      topStr = media.rawAttributes['resolvedTop'] ?? '0%';
      widthStr = media.rawAttributes['resolvedWidth'] ?? '100%';
      heightStr = media.rawAttributes['resolvedHeight'] ?? '100%';
    }
    if (leftVal != null) leftStr = leftVal;
    if (topVal != null) topStr = topVal;
    if (widthVal != null) widthStr = widthVal;
    if (heightVal != null) heightStr = heightVal;
    if (zIndexVal != null) {
      zindex = int.tryParse(zIndexVal) ?? 0;
    } else if (media.rawAttributes.containsKey('resolvedZIndex')) {
      zindex = int.tryParse(media.rawAttributes['resolvedZIndex']!) ?? 0;
    } else {
      zindex = 0;
    }
    final visibleStr = media.rawAttributes['visible'] ?? 'true';
    visible = visibleStr.toLowerCase() == 'true';
    background = _parseColor(backgroundVal);
    focusBorderColor = _parseColor(media.rawAttributes['focusBorderColor']);
    selBorderColor = _parseColor(media.rawAttributes['selBorderColor']);
  }

  void syncProperties() {
    if (mounted) {
      setState(() {
        parseProperties(widget.media);
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

  Future<String> loadContent(String path) async {
    if (kIsWeb) {
      try {
        final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
        if (mockJson != null) {
          final mockFiles = jsonDecode(mockJson);
          final fileName = Uri.parse(path).pathSegments.last;
          if (mockFiles.containsKey(fileName)) {
            return mockFiles[fileName];
          }
        }
      } catch (e) {
        // Ignore JSON errors
      }
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode == 200) {
        return response.body;
      }
      throw Exception('Failed to load $path: ${response.statusCode}');
    }
    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return await file.readAsString();
      }
      final fileName =
          path.contains('/') ? path.substring(path.lastIndexOf('/') + 1) : path;
      final localFile = File(fileName);
      if (localFile.existsSync()) {
        return await localFile.readAsString();
      }
    }
    final bundle =
        context.getInheritedWidgetOfExactType<DefaultAssetBundle>()?.bundle ??
            rootBundle;
    return await bundle.loadString(path);
  }

  String get playerKey => id ?? '';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    double left, top, width, height;
    left = _resolveDim(leftStr, screenWidth);
    top = _resolveDim(topStr, screenHeight);
    width = _resolveDim(widthStr, screenWidth);
    height = _resolveDim(heightStr, screenHeight);
    rect = Rect.fromLTWH(left, top, width, height);

    final content = Visibility(
      visible: visible,
      child: Opacity(
        opacity: alpha / 255.0,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: selBorderColor != Colors.transparent
                ? Border.all(color: selBorderColor, width: 3.0)
                : (focusBorderColor != Colors.transparent
                    ? Border.all(color: focusBorderColor, width: 2.0)
                    : null),
          ),
          child: buildWidgetContent(context),
        ),
      ),
    );
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
class WidgetFactory {
  static Widget? createMediaWidget({
    Key? key,
    required Media media,
    MainAVController? mainAVController,
  }) {
    final mimeType = media.mimeType;
    var uri = media.uri;
    if (uri.startsWith('sbtvd://')) {
      if (mainAVController != null) {
        var avUri = mainAVController.uri ?? '';
        if (avUri.isEmpty || avUri.startsWith('sbtvd://')) {
          avUri =
              'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
        }
        return AVWidget(
          key: key,
          uri: avUri,
          media: media,
        );
      }
      return null;
    }
    if (kIsWeb) {
      try {
        final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
        if (mockJson != null) {
          final mockFiles = jsonDecode(mockJson);
          final fileName = Uri.parse(uri).pathSegments.last;
          if (mockFiles.containsKey(fileName)) {
            uri = mockFiles[fileName];
          }
        }
      } catch (e) {}
    }
    if (uri.endsWith('.ncl') ||
        mimeType == 'application/x-ncl-NCL' ||
        mimeType == 'application/x-ncl-ncl') {
      return NCLApp(key: key, uri: uri, media: media);
    }
    if (mimeType.startsWith('video/') ||
        mimeType.startsWith('audio/') ||
        mimeType.contains('video') ||
        mimeType.contains('audio')) {
      return AVWidget(key: key, uri: uri, media: media);
    }
    switch (mimeType) {
      case 'application/x-ncl-NCLua':
      case 'application/x-ginga-NCLua':
        return LuaWidget(key: key, uri: uri, media: media);
      case 'application/ssml+xml':
        return SsmlWidget(key: key, uri: uri, media: media);
      case 'text/plain':
        return TextWidget(key: key, uri: uri, media: media);
      case 'text/html':
        return HtmlWidget(key: key, uri: uri, media: media);
      case 'image/png':
      case 'image/jpeg':
      case 'image/gif':
      case 'image/webp':
      case 'image/bmp':
      case 'image/heic':
      case 'application/x-ginga-time':
      case 'application/x-ncl-time':
        return ImageWidget(key: key, uri: uri, media: media);
      default:
        return null;
    }
  }
}
