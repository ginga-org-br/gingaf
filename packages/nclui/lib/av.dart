import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ncldoc/elements.dart';
import 'package:ncldoc/event.dart';
import 'package:video_player/video_player.dart';

import 'ncl.dart';

class AVWidget extends BaseWidget {
  const AVWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
  });

  @override
  AVWidgetState createState() => AVWidgetState();
}

class AVWidgetState<T extends AVWidget> extends MediaState<T> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isCompleted = false;
  bool _isPaused = false;
  String _activeSrc = '';
  String _targetSrc = '';
  bool _isSwitching = false;
  final Set<VideoPlayerController> _disposedControllers = {};
  // Web browsers block programmatic autoplay for media with audio tracks unless muted.
  // Setting volume to 0.0 applies the muted attribute to HTMLVideoElement, allowing autoplay.
  // See: https://developer.mozilla.org/en-US/docs/Web/Media/Autoplay_guide
  bool _isMutedForAutoplay = false;

  VideoPlayerController? get controller => _controller;
  bool get initialized => _initialized;
  bool get isPlaying => true;
  bool get isLooping => false;
  bool get notifyCompletion => true;
  bool get isPaused => _isPaused;

  void unmute() {
    if (kIsWeb && _controller != null && soundLevel > 0) {
      _isMutedForAutoplay = false;
      _controller!.setVolume(soundLevel);
    }
  }

  @override
  void pause() {
    _isPaused = true;
    _controller?.pause();
    if (mounted) setState(() {});
  }

  @override
  void resume() {
    _isPaused = false;
    if (isPlaying) {
      _controller?.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void forward(Duration duration) {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final newPos = c.value.position + duration;
      c.seekTo(newPos);
      if (notifyCompletion &&
          !_isCompleted &&
          c.value.duration.inMilliseconds > 0 &&
          newPos >= c.value.duration) {
        _isCompleted = true;
        final media = widget.media;
        if (media != null && mounted) {
          final appState = context.findAncestorStateOfType<NclWidgetState>();
          if (appState != null && appState.nclDocument != null) {
            appState.nclDocument!.uiQueue.add(
              NclAction(
                event: media.getMainNclEvent(),
                action: NclActionType.stop,
              ),
            );
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
    _targetSrc = widget.src.trim();
    initVideo();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSrc = widget.src.trim();
    if (newSrc != _targetSrc) {
      _targetSrc = newSrc;
      _switchToTargetVideo();
    }
  }

  @override
  void parseProperties([Media? targetMedia]) {
    super.parseProperties(targetMedia);
    if (!kIsWeb || !_isMutedForAutoplay) {
      _controller?.setVolume(soundLevel);
    }
  }

  void _onVideoPositionChanged() {
    final c = _controller;
    if (c != null &&
        !_isCompleted &&
        c.value.isInitialized &&
        c.value.duration.inMilliseconds > 0 &&
        c.value.position >= c.value.duration) {
      _isCompleted = true;
      final media = widget.media;
      if (media != null && mounted) {
        final appState = context.findAncestorStateOfType<NclWidgetState>();
        if (appState != null && appState.nclDocument != null) {
          appState.nclDocument!.uiQueue.add(
            NclAction(
              event: media.getMainNclEvent(),
              action: NclActionType.stop,
            ),
          );
        }
      }
    }
  }

  Future<void> _safeDisposeController(VideoPlayerController c) async {
    if (_disposedControllers.contains(c)) return;
    _disposedControllers.add(c);
    if (notifyCompletion) {
      try {
        c.removeListener(_onVideoPositionChanged);
      } catch (_) {}
    }
    try {
      await c.pause();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  Future<void> _switchToTargetVideo() async {
    if (_isSwitching) return;
    _isSwitching = true;
    try {
      while (mounted && _targetSrc.isNotEmpty && _targetSrc != _activeSrc) {
        final nextSrc = _targetSrc;
        final prev = _controller;
        if (prev != null) {
          _controller = null;
          _initialized = false;
          _isCompleted = false;
          if (mounted) {
            setState(() {});
          }
          await _safeDisposeController(prev);
        }
        if (!mounted) break;
        if (_targetSrc != nextSrc) continue;
        await _initVideoForSrc(nextSrc);
      }
    } finally {
      _isSwitching = false;
    }
  }

  Future<void> initVideo() async {
    _targetSrc = widget.src.trim();
    if (_targetSrc.isEmpty) return;
    await _switchToTargetVideo();
  }

  Future<void> _initVideoForSrc(String srcToLoad) async {
    if (srcToLoad.trim().isEmpty) return;
    try {
      final parsedUri = widget.privateBase.resolveUri(srcToLoad);
      final VideoPlayerController controller;

      if (kIsWeb || (parsedUri.hasScheme && parsedUri.scheme != 'file')) {
        controller = VideoPlayerController.networkUrl(parsedUri);
      } else if (parsedUri.isScheme('file')) {
        controller = VideoPlayerController.file(File(parsedUri.toFilePath()));
      } else {
        controller = VideoPlayerController.file(
            File(Uri.decodeComponent(parsedUri.path)));
      }

      _controller = controller;
      _activeSrc = srcToLoad;

      if (notifyCompletion) {
        controller.addListener(_onVideoPositionChanged);
      }

      await controller.initialize();
      if (!mounted || _controller != controller) {
        await _safeDisposeController(controller);
        return;
      }
      if (isLooping) {
        await controller.setLooping(true);
      }
      if (kIsWeb) {
        _isMutedForAutoplay = true;
        await controller.setVolume(0.0);
      } else {
        await controller.setVolume(soundLevel);
      }
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }

      if (isPlaying && !_isPaused) {
        try {
          await controller.play();
        } catch (playErr) {
          debugPrint("AVWidget play error: $playErr");
        }
      }
    } catch (e) {
      debugPrint("AVWidget Error initializing video: $e");
    }
  }

  @override
  void dispose() {
    final prev = _controller;
    _controller = null;
    if (prev != null) {
      _safeDisposeController(prev);
    }
    super.dispose();
  }

  Widget buildLoadingWidget(BuildContext context) {
    if (widget.media != null) {
      return const SizedBox.shrink();
    }
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    final controller = _controller;
    if (!_initialized || controller == null || !isPlaying) {
      return buildLoadingWidget(context);
    }
    final size = controller.value.size;
    final Widget player = (size.width > 0 && size.height > 0)
        ? FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          )
        : VideoPlayer(controller);

    return Container(
      color: Colors.black,
      child: SizedBox.expand(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: unmute,
          child: player,
        ),
      ),
    );
  }
}
