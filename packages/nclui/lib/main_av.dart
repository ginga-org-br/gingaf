import 'package:flutter/material.dart';

import 'ncl.dart';

class MainAVWidget extends AVWidget {
  const MainAVWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
  });

  @override
  MainAVWidgetState createState() => MainAVWidgetState();
}

class MainAVWidgetState extends AVWidgetState<MainAVWidget> {
  bool _isPlaying = true;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isLooping => true;

  @override
  bool get notifyCompletion => false;

  void play() {
    _isPlaying = true;
    controller?.play();
    if (mounted) setState(() {});
  }

  void stop() {
    _isPlaying = false;
    controller?.pause();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final parentBounds = NclWidget.maybeOf(context)?.bounds;
    if (parentBounds != null) {
      return super.build(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final double planeWidth =
            (constraints.hasBoundedWidth && constraints.maxWidth > 0)
                ? constraints.maxWidth
                : (MediaQuery.maybeOf(context)?.size.width ?? 720.0);
        final double planeHeight =
            (constraints.hasBoundedHeight && constraints.maxHeight > 0)
                ? constraints.maxHeight
                : (MediaQuery.maybeOf(context)?.size.height ?? 480.0);

        rect = Rect.fromLTWH(0.0, 0.0, planeWidth, planeHeight);

        return buildWidgetContent(context);
      },
    );
  }

  @override
  Widget buildLoadingWidget(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie, size: 64, color: Colors.white70),
            const SizedBox(height: 8),
            Text(
              "Loading MainAV: ${widget.src}",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
