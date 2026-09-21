import 'dart:convert';

export 'package:ncldoc/ncl_strings.dart' show NclKeys;

class AppRecoderConfig {
  final String appSrc;
  final String? outputDir;
  final Duration duration;
  final Duration stepDuration;
  final int? fps;
  final Map<int, String> keyEvents;
  final Map<int, String> userEvents;

  const AppRecoderConfig({
    required this.appSrc,
    this.outputDir,
    this.duration = const Duration(seconds: 5),
    this.stepDuration = const Duration(milliseconds: 200),
    this.fps,
    this.keyEvents = const {},
    this.userEvents = const {},
  });

  Map<String, dynamic> toJson() => {
        'appSrc': appSrc,
        if (outputDir != null) 'outputDir': outputDir,
        'durationMs': duration.inMilliseconds,
        'stepDurationMs': stepDuration.inMilliseconds,
        if (fps != null) 'fps': fps,
        'keyEvents': keyEvents.map((k, v) => MapEntry(k.toString(), v)),
        'userEvents': userEvents.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory AppRecoderConfig.fromJson(Map<String, dynamic> json) {
    final rawKeyEvents = json['keyEvents'] as Map<String, dynamic>? ?? {};
    final keyEvents = rawKeyEvents.map(
      (k, v) => MapEntry(int.parse(k), v.toString()),
    );
    final rawUserEvents = json['userEvents'] as Map<String, dynamic>? ?? {};
    final userEvents = rawUserEvents.map(
      (k, v) => MapEntry(int.parse(k), v.toString()),
    );

    return AppRecoderConfig(
      appSrc: json['appSrc'] as String,
      outputDir: json['outputDir'] as String?,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 5000),
      stepDuration:
          Duration(milliseconds: json['stepDurationMs'] as int? ?? 200),
      fps: json['fps'] as int?,
      keyEvents: keyEvents,
      userEvents: userEvents,
    );
  }

  AppRecoderConfig copyWith({
    String? appSrc,
    String? outputDir,
    Duration? duration,
    Duration? stepDuration,
    int? fps,
    Map<int, String>? keyEvents,
    Map<int, String>? userEvents,
  }) {
    return AppRecoderConfig(
      appSrc: appSrc ?? this.appSrc,
      outputDir: outputDir ?? this.outputDir,
      duration: duration ?? this.duration,
      stepDuration: stepDuration ?? this.stepDuration,
      fps: fps ?? this.fps,
      keyEvents: keyEvents ?? this.keyEvents,
      userEvents: userEvents ?? this.userEvents,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AppRecoderConfig.fromJsonString(String source) =>
      AppRecoderConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory AppRecoderConfig.fromCli(String input) {
    var raw = input.trim();
    if (raw.startsWith("'") && raw.endsWith("'") && raw.length > 1) {
      raw = raw.substring(1, raw.length - 1).trim();
    }
    if (raw.startsWith('"') && raw.endsWith('"') && raw.length > 1) {
      raw = raw.substring(1, raw.length - 1).trim();
    }
    if (raw.contains(r'\"')) {
      raw = raw.replaceAll(r'\"', '"');
    }
    return AppRecoderConfig.fromJsonString(raw);
  }
}

typedef AppRecorderConfig = AppRecoderConfig;
