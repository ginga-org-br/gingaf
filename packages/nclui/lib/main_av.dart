import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'base_widget.dart';

class MainAVWidget extends BaseWidget {
  const MainAVWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
  });

  @override
  MainAVWidgetState createState() => MainAVWidgetState();
}

class MainAVWidgetState extends MediaState<MainAVWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = true;

  bool get isPlaying => _isPlaying;

  void play() {
    _isPlaying = true;
    _controller?.play();
    if (mounted) setState(() {});
  }

  void stop() {
    _isPlaying = false;
    _controller?.pause();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.src.trim().isEmpty) return;
    try {
      final gingacc = widget.document?.gingacc ?? GingaCC();
      final parsedUri = gingacc.resolveUri(widget.src);
      final src = parsedUri.toString();
      final VideoPlayerController controller;

      if (kIsWeb || (parsedUri.hasScheme && parsedUri.scheme != 'file')) {
        controller = VideoPlayerController.networkUrl(parsedUri);
      } else if (parsedUri.isScheme('file')) {
        controller = VideoPlayerController.file(File(parsedUri.toFilePath()));
      } else {
        controller = VideoPlayerController.file(File(src));
      }

      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }

      if (_isPlaying) {
        try {
          await controller.play();
        } catch (playErr) {
          debugPrint("MainAVWidget play error: $playErr");
        }
      }
    } catch (e) {
      debugPrint("MainAVWidget Error initializing video: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    final controller = _controller;
    if (!_initialized || controller == null || !_isPlaying) {
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
    return Container(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
