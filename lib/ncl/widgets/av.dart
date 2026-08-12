import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Action;
import 'package:ncldoc/event.dart';
import 'package:video_player/video_player.dart';

import '../ncl_app.dart';

class AVWidget extends MediaWidget {
  AVWidget({
    super.key,
    required super.src,
    super.media,
    super.config,
  });

  @override
  State<AVWidget> createState() => AVWidgetState();
}

class AVWidgetState extends MediaState<AVWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.src.trim().isEmpty) return;
    try {
      final loader = widget.config.contentLoader..setBuildContext(context);
      final parsedUri = loader.resolveUri(widget.src);
      assert(loader.exists(parsedUri));
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

      controller.addListener(() {
        if (!_isCompleted &&
            controller.value.isInitialized &&
            controller.value.duration.inMilliseconds > 0 &&
            controller.value.position >= controller.value.duration) {
          _isCompleted = true;
          final media = widget.media;
          if (media != null && mounted) {
            final appState = context.findAncestorStateOfType<NCLAppState>();
            if (appState != null && appState.nclDocument != null) {
              appState.nclDocument!.uiQueue.add(
                Action(
                  event: media.getMainEvent(),
                  action: NCLAction.STOP,
                ),
              );
            }
          }
        }
      });

      await controller.initialize();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }

      if (kIsWeb) {
        await controller.setVolume(0.0);
      }
      try {
        await controller.play();
      } catch (playErr) {
        debugPrint("AVWidget play error (e.g. autoplay blocked): $playErr");
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

  @override
  Widget buildWidgetContent(BuildContext context) {
    final controller = _controller;
    if (!_initialized || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
