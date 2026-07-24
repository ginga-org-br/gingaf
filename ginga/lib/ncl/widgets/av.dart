import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Action;
import 'package:ncldoc/event.dart' hide State;
import 'package:video_player/video_player.dart';

import '../ncl_app.dart';
import 'ncl_media_widget.dart';

class AVWidget extends MediaWidget {
  const AVWidget({
    super.key,
    required super.uri,
    super.media,
  });

  @override
  State<AVWidget> createState() => AVWidgetState();
}

class AVWidgetState extends MediaState<AVWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final uriStr = widget.uri;
      if (uriStr.startsWith('http://') || uriStr.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(uriStr));
      } else {
        if (kIsWeb) {
          _controller = VideoPlayerController.networkUrl(Uri.parse(uriStr));
        } else {
          _controller = VideoPlayerController.file(File(uriStr));
        }
      }

      _controller.addListener(() {
        if (!_isCompleted &&
            _controller.value.isInitialized &&
            _controller.value.duration.inMilliseconds > 0 &&
            _controller.value.position >= _controller.value.duration) {
          _isCompleted = true;
          final media = widget.media;
          if (media != null && mounted) {
            final appState = context.findAncestorStateOfType<NCLAppState>();
            if (appState != null && appState.nclDocument != null) {
              appState.nclDocument!.uiQueue.add(
                Action(
                  event: media.getMainEvent(),
                  action: ActionType.STOP,
                ),
              );
            }
          }
        }
      });

      await _controller.initialize();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }

      if (kIsWeb) {
        await _controller.setVolume(0.0);
      }
      try {
        await _controller.play();
      } catch (playErr) {
        debugPrint("AVWidget play error (e.g. autoplay blocked): $playErr");
      }
    } catch (e) {
      debugPrint("AVWidget Error initializing video: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
