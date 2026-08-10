import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MainAVController extends ChangeNotifier {
  String? _uri;
  bool _isPlaying = true;

  String? get uri => _uri;
  bool get isPlaying => _isPlaying;

  void setMainAvUri(String? val) {
    if (_uri != val) {
      _uri = val;
      notifyListeners();
    }
  }

  void play() {
    if (!_isPlaying) {
      _isPlaying = true;
      notifyListeners();
    }
  }

  void stop() {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
    }
  }
}

class MainAVWidget extends StatefulWidget {
  final MainAVController controller;

  const MainAVWidget({super.key, required this.controller});

  @override
  State<MainAVWidget> createState() => _MainAVWidgetState();
}

class _MainAVWidgetState extends State<MainAVWidget> {
  String? _currentUri;
  VideoPlayerController? _videoController;

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _initializeVideo();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      _videoController!.dispose();
    }
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) {
      if (_currentUri != widget.controller.uri) {
        // URI changed, reinitialize
        if (_videoController != null) {
          _videoController!.removeListener(_videoListener);
          _videoController!.dispose();
          _videoController = null;
        }
        _initializeVideo();
      } else {
        // Just play/stop state changed
        if (_videoController != null) {
          if (widget.controller.isPlaying) {
            _videoController!.play();
          } else {
            _videoController!.pause();
          }
        }
        setState(() {});
      }
    }
  }

  Future<void> _initializeVideo() async {
    final uriStr = widget.controller.uri;
    _currentUri = uriStr;

    if (uriStr == null || uriStr.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final VideoPlayerController controller;
      if (uriStr.startsWith('http://') || uriStr.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(uriStr));
      } else {
        if (kIsWeb) {
          controller = VideoPlayerController.networkUrl(Uri.parse(uriStr));
        } else {
          controller = VideoPlayerController.file(File(uriStr));
        }
      }

      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_videoListener);

      if (mounted) {
        setState(() {});
      }

      if (widget.controller.isPlaying) {
        try {
          await controller.play();
        } catch (playErr) {
          debugPrint("MainAVWidget play error (e.g. autoplay blocked): $playErr");
          if (kIsWeb) {
            await controller.setVolume(0.0);
            try {
              await controller.play();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint("MainAVWidget Error initializing video: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = widget.controller.uri;
    final isPlaying = widget.controller.isPlaying;

    if (uri == null || uri.isEmpty || !isPlaying) {
      return Container(color: Colors.black);
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie, size: 64, color: Colors.white70),
            const SizedBox(height: 8),
            Text(
              "Loading Background AV: $uri",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
