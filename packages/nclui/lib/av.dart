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

  VideoPlayerController? get controller => _controller;
  bool get initialized => _initialized;
  bool get isPlaying => true;
  bool get isLooping => false;
  bool get notifyCompletion => true;
  bool get isPaused => _isPaused;

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
  void initState() {
    super.initState();
    parseProperties(widget.media);
    initVideo();
  }

  @override
  void parseProperties([Media? targetMedia]) {
    super.parseProperties(targetMedia);
    _controller?.setVolume(soundLevel);
  }

  void _onVideoPositionChanged() {
    if (_isPaused) return;
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

  Future<void> initVideo() async {
    if (widget.src.trim().isEmpty) return;
    try {
      final gingacc = widget.document?.gingacc ?? GingaCC();
      final parsedUri = gingacc.resolveUri(widget.src);
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

      if (notifyCompletion) {
        controller.addListener(_onVideoPositionChanged);
      }

      await controller.initialize();
      if (isLooping) {
        await controller.setLooping(true);
      }
      await controller.setVolume(soundLevel);

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
    _controller?.dispose();
    super.dispose();
  }

  Widget buildLoadingWidget(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    final controller = _controller;
    if (!_initialized || controller == null || !isPlaying) {
      return buildLoadingWidget(context);
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
