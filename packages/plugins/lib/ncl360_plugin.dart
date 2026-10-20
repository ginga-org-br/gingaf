import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/base_widget.dart';
import 'package:nclui/nclui_plugins.dart';

import 'plugin_base.dart';

class Ncl360MediaPlugin implements NclMediaPlugin, PluginBase {
  @override
  PluginType get type => PluginType.optional;

  @override
  bool canHandle(String src, String? mimeType) {
    final lowerSrc = src.toLowerCase();
    if (lowerSrc.endsWith('.360.jpg') ||
        lowerSrc.endsWith('.360.jpeg') ||
        lowerSrc.endsWith('.360.png') ||
        lowerSrc.endsWith('.360.webp') ||
        lowerSrc.endsWith('.360.mp4') ||
        lowerSrc.endsWith('.pano') ||
        lowerSrc.endsWith('.360')) {
      return true;
    }
    if (mimeType == 'image/360' ||
        mimeType == 'video/360' ||
        mimeType == 'application/x-ginga-360' ||
        mimeType == 'application/x-ncl-360') {
      return true;
    }
    return false;
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
    return Scene360Widget(
      key: key,
      src: src,
      mimeType: mimeType,
      media: media,
      document: document,
      focusNode: focusNode,
    );
  }
}

class Scene360Widget extends BaseWidget {
  final String? mimeType;
  final FocusNode? focusNode;

  const Scene360Widget({
    super.key,
    required super.src,
    this.mimeType,
    super.media,
    super.document,
    this.focusNode,
  });

  @override
  State<Scene360Widget> createState() => _Scene360WidgetState();
}

class _Scene360WidgetState extends MediaState<Scene360Widget> {
  double yaw = 0.0;
  double pitch = 0.0;
  double roll = 0.0;
  double fieldOfView = 90.0;

  ui.Image? _loadedImage;
  bool _isLoading = true;
  String? _errorMessage;
  late final FocusNode _internalFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _extractInitialProperties();
    _loadImage();
  }

  void _extractInitialProperties() {
    final m = widget.media;
    if (m == null) return;

    String? rawYaw;
    String? rawPitch;
    String? rawRoll;
    String? rawFov;

    for (final prop in m.getProperties()) {
      if (prop.name == 'yaw') rawYaw = prop.value;
      if (prop.name == 'pitch') rawPitch = prop.value;
      if (prop.name == 'roll') rawRoll = prop.value;
      if (prop.name == 'fieldOfView' || prop.name == 'fov') rawFov = prop.value;
    }

    final desc = widget.document?.getDescriptorForMedia(m);
    if (desc != null) {
      for (final param in desc.children.whereType<DescriptorParam>()) {
        if (param.name == 'yaw') rawYaw ??= param.value;
        if (param.name == 'pitch') rawPitch ??= param.value;
        if (param.name == 'roll') rawRoll ??= param.value;
        if (param.name == 'fieldOfView' || param.name == 'fov') {
          rawFov ??= param.value;
        }
      }
    }

    if (rawYaw != null) {
      yaw = double.tryParse(rawYaw) ?? yaw;
    }
    if (rawPitch != null) {
      pitch = double.tryParse(rawPitch) ?? pitch;
    }
    if (rawRoll != null) {
      roll = double.tryParse(rawRoll) ?? roll;
    }
    if (rawFov != null) {
      fieldOfView = double.tryParse(rawFov) ?? fieldOfView;
    }
  }

  void _loadImage() {
    if (widget.src.trim().isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final parsedUri = widget.privateBase.resolveUri(widget.src);

      ImageProvider provider;
      if (kIsWeb ||
          parsedUri.scheme == 'http' ||
          parsedUri.scheme == 'https' ||
          parsedUri.scheme == 'data') {
        provider = NetworkImage(parsedUri.toString());
      } else {
        final filePath = parsedUri.isScheme('file')
            ? parsedUri.toFilePath()
            : parsedUri.path;
        final file = File(filePath);
        if (file.existsSync()) {
          provider = FileImage(file);
        } else {
          provider = AssetImage(widget.src);
        }
      }

      final stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener(
          (info, _) {
            if (mounted) {
              setState(() {
                _loadedImage = info.image;
                _isLoading = false;
              });
            }
          },
          onError: (dynamic error, StackTrace? stackTrace) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      yaw = (yaw - details.delta.dx * 0.3) % 360.0;
      pitch = (pitch + details.delta.dy * 0.3).clamp(-85.0, 85.0);
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    setState(() {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        yaw = (yaw - 5.0) % 360.0;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        yaw = (yaw + 5.0) % 360.0;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        pitch = (pitch + 5.0).clamp(-85.0, 85.0);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        pitch = (pitch - 5.0).clamp(-85.0, 85.0);
      } else if (event.logicalKey == LogicalKeyboardKey.equal ||
          event.logicalKey == LogicalKeyboardKey.numpadAdd ||
          event.logicalKey == LogicalKeyboardKey.pageUp) {
        fieldOfView = (fieldOfView - 5.0).clamp(30.0, 120.0);
      } else if (event.logicalKey == LogicalKeyboardKey.minus ||
          event.logicalKey == LogicalKeyboardKey.numpadSubtract ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        fieldOfView = (fieldOfView + 5.0).clamp(30.0, 120.0);
      }
    });
  }

  @override
  void dispose() {
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            '360 Media Error: $_errorMessage',
            style: const TextStyle(color: Colors.redAccent, fontSize: 14.0),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return KeyboardListener(
      focusNode: _effectiveFocusNode,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onPanUpdate: _handlePanUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: EquirectangularPainter(
                image: _loadedImage,
                yaw: yaw,
                pitch: pitch,
                roll: roll,
                fov: fieldOfView,
              ),
            ),
            Positioned(
              left: 8.0,
              bottom: 8.0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  '360° | Yaw: ${yaw.toStringAsFixed(1)}° | Pitch: ${pitch.toStringAsFixed(1)}° | FoV: ${fieldOfView.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.0,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EquirectangularPainter extends CustomPainter {
  final ui.Image? image;
  final double yaw;
  final double pitch;
  final double roll;
  final double fov;

  EquirectangularPainter({
    required this.image,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.fov,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      final bgPaint = Paint()..color = const Color(0xFF101015);
      canvas.drawRect(Offset.zero & size, bgPaint);
      _drawGrid(canvas, size);
      return;
    }

    final img = image!;
    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();

    final visibleNormalizedW = (fov / 360.0).clamp(0.1, 1.0);
    final visibleNormalizedH = (fov / 180.0).clamp(0.1, 1.0);

    final normYaw = ((yaw % 360.0) + 360.0) % 360.0 / 360.0;
    final normPitch = ((-pitch + 90.0).clamp(0.0, 180.0)) / 180.0;

    final srcCenterX = normYaw * imgW;
    final srcCenterY = normPitch * imgH;

    final srcW = visibleNormalizedW * imgW;
    final srcH = visibleNormalizedH * imgH;

    final srcLeft = srcCenterX - srcW / 2.0;
    final srcTop = (srcCenterY - srcH / 2.0).clamp(0.0, imgH - srcH);

    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (srcLeft < 0) {
      final leftPartWidth = -srcLeft;
      final rightPartWidth = srcW - leftPartWidth;

      final src1 =
          Rect.fromLTWH(imgW - leftPartWidth, srcTop, leftPartWidth, srcH);
      final dest1 = Rect.fromLTWH(
        0,
        0,
        size.width * (leftPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src1, dest1, Paint());

      final src2 = Rect.fromLTWH(0, srcTop, rightPartWidth, srcH);
      final dest2 = Rect.fromLTWH(
        dest1.width,
        0,
        size.width * (rightPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src2, dest2, Paint());
    } else if (srcLeft + srcW > imgW) {
      final leftPartWidth = imgW - srcLeft;
      final rightPartWidth = srcW - leftPartWidth;

      final src1 = Rect.fromLTWH(srcLeft, srcTop, leftPartWidth, srcH);
      final dest1 = Rect.fromLTWH(
        0,
        0,
        size.width * (leftPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src1, dest1, Paint());

      final src2 = Rect.fromLTWH(0, srcTop, rightPartWidth, srcH);
      final dest2 = Rect.fromLTWH(
        dest1.width,
        0,
        size.width * (rightPartWidth / srcW),
        size.height,
      );
      canvas.drawImageRect(img, src2, dest2, Paint());
    } else {
      final srcRect = Rect.fromLTWH(srcLeft, srcTop, srcW, srcH);
      canvas.drawImageRect(img, srcRect, destRect, Paint());
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2E3345)
      ..strokeWidth = 1.0;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var x = 0.0; x < size.width; x += 40.0) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 40.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    textPainter.text = TextSpan(
      text:
          '360 Panoramic Viewport (Equirectangular Projection)\nYaw: ${yaw.toStringAsFixed(1)}° | Pitch: ${pitch.toStringAsFixed(1)}° | FoV: ${fov.toStringAsFixed(1)}°',
      style: const TextStyle(color: Color(0xFF8892B0), fontSize: 13.0),
    );
    textPainter.layout(maxWidth: size.width - 32.0);
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2.0,
        (size.height - textPainter.height) / 2.0,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant EquirectangularPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.fov != fov ||
        oldDelegate.image != image;
  }
}
