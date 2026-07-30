import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVideoPlayer extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  int _nextTextureId = 1;
  final Map<int, StreamController<VideoEvent>> _controllers = {};
  final StreamController<VideoEvent> events = StreamController<VideoEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {
    await _controllers[textureId]?.close();
    _controllers.remove(textureId);
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    final textureId = _nextTextureId++;
    final controller = StreamController<VideoEvent>.broadcast();
    _controllers[textureId] = controller;
    events.stream.listen((event) {
      if (!controller.isClosed) {
        controller.add(event);
      }
    });
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 10),
          size: const Size(1920, 1080),
        ));
      }
    });
    return textureId;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async {
    return Duration.zero;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _controllers[textureId]?.stream ?? const Stream.empty();
  }

  @override
  Widget buildView(int textureId) {
    return Container();
  }
}
