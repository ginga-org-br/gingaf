import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

      controller.addListener(() {
        if (!_isCompleted &&
            controller.value.isInitialized &&
            controller.value.duration.inMilliseconds > 0 &&
            controller.value.position >= controller.value.duration) {
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
      });

      await controller.initialize();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }

      try {
        await controller.play();
      } catch (playErr) {
        debugPrint("AVWidget play error: $playErr");
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
