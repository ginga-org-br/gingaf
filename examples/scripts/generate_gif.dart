import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../integration_test/app_recorder_config.dart';

const Map<String, AppRecoderConfig> scenarios = {
  'video.ncl': AppRecoderConfig(
    appSrc: 'examples/video.ncl',
    duration: Duration(seconds: 6),
    stepDuration: Duration(milliseconds: 200),
  ),
  'video_grid.ncl': AppRecoderConfig(
    appSrc: 'examples/video_grid.ncl',
    duration: Duration(seconds: 5),
    stepDuration: Duration(milliseconds: 200),
  ),
  'emb_ncl.ncl': AppRecoderConfig(
    appSrc: 'examples/emb_ncl.ncl',
    duration: Duration(seconds: 6),
    stepDuration: Duration(milliseconds: 200),
  ),
  'current_service.html': AppRecoderConfig(
    appSrc: 'examples/current_service.html',
    duration: Duration(seconds: 4),
    stepDuration: Duration(milliseconds: 250),
  ),
  'emb_html.ncl': AppRecoderConfig(
    appSrc: 'examples/emb_html.ncl',
    duration: Duration(seconds: 5),
    stepDuration: Duration(milliseconds: 250),
  ),
  'lua_canvas.ncl': AppRecoderConfig(
    appSrc: 'examples/lua_canvas.ncl',
    duration: Duration(seconds: 6),
    stepDuration: Duration(milliseconds: 250),
    keyEvents: {
      4: NclKeys.cursorRight,
      6: NclKeys.cursorRight,
      8: NclKeys.cursorDown,
      10: NclKeys.cursorDown,
      12: NclKeys.cursorLeft,
      14: NclKeys.cursorLeft,
      16: NclKeys.cursorUp,
      18: NclKeys.cursorUp,
      20: NclKeys.cursorRight,
      22: NclKeys.cursorDown,
    },
  ),
  'focus_nav.ncl': AppRecoderConfig(
    appSrc: 'examples/focus_nav.ncl',
    duration: Duration(seconds: 6),
    stepDuration: Duration(milliseconds: 250),
    keyEvents: {
      3: NclKeys.cursorRight,
      5: NclKeys.enter,
      8: NclKeys.cursorRight,
      10: NclKeys.enter,
      13: NclKeys.cursorRight,
      15: NclKeys.enter,
      18: NclKeys.cursorRight,
      20: NclKeys.enter,
    },
  ),
  'multiuser_profile/main.ncl': AppRecoderConfig(
    appSrc: 'examples/multiuser_profile/main.ncl',
    duration: Duration(seconds: 18),
    stepDuration: Duration(milliseconds: 300),
    fps: 3,
    userEvents: {
      9: 'open_users',
      15: 'u2',
      25: 'open_users',
      31: 'u3',
      41: 'open_users',
      47: 'u1',
    },
  ),
  'multiuser_current/main.ncl': AppRecoderConfig(
    appSrc: 'examples/multiuser_current/main.ncl',
    duration: Duration(seconds: 18),
    stepDuration: Duration(milliseconds: 300),
    fps: 3,
    userEvents: {
      9: 'open_users',
      15: 'u2',
      25: 'open_users',
      31: 'u3',
      41: 'open_users',
      47: 'u1',
    },
  ),
};

const defaultTargets = [
  'video.ncl',
  'video_grid.ncl',
  'emb_ncl.ncl',
  'current_service.html',
  'emb_html.ncl',
  'lua_canvas.ncl',
  'focus_nav.ncl',
  'multiuser_profile/main.ncl',
  'multiuser_current/main.ncl',
];

String getPlatformDevice() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'chrome';
}

Directory findProjectRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current;
    }
    dir = parent;
  }
  return dir;
}

String resolveAppSrc(String target) {
  final clean = target.replaceFirst(RegExp(r'^examples[/\\]'), '');
  return 'examples/$clean';
}

Future<void> main(List<String> args) async {
  final projectRoot = findProjectRoot();
  final targets = args.isNotEmpty
      ? args.map((a) => a.replaceFirst(RegExp(r'^examples[/\\]'), '')).toList()
      : defaultTargets;

  for (final t in targets) {
    if (!t.contains('.') || t.endsWith('.')) {
      stderr.writeln(
          'Error: Target "$t" must include a file extension (e.g. "$t.ncl").');
      exit(1);
    }
  }

  final device = getPlatformDevice();
  const fps = 8;
  const width = 640;

  final generatedGifs = <File>[];

  for (var i = 0; i < targets.length; i++) {
    final t = targets[i];
    final appSrc = resolveAppSrc(t);
    final appFile = File('${projectRoot.path}/$appSrc');
    final targetFile = appFile.uri.pathSegments.last;

    final scenario = (scenarios[t] ?? AppRecoderConfig(appSrc: appSrc))
        .copyWith(outputDir: 'build/captures/$t');

    final configJson = scenario.toJsonString();

    if (i > 0) stdout.writeln('');
    stdout.writeln('===============================================');
    stdout.writeln('Capturing frames for target: $targetFile');
    stdout.writeln('===============================================');

    final capturesDir = Directory('${projectRoot.path}/build/captures/$t');
    if (capturesDir.existsSync()) {
      try {
        capturesDir.deleteSync(recursive: true);
      } catch (_) {}
    }

    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'gingaf.exe'],
            runInShell: true);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    final flutterProcess = await Process.start(
      'flutter',
      [
        'run',
        '--release',
        '-d',
        device,
        '-t',
        'integration_test/app_recorder.dart',
        '--dart-define=CONFIG=${configJson.replaceAll('"', r'\"')}',
        '-a',
        configJson.replaceAll('"', r'\"'),
        '--no-pub',
      ],
      runInShell: true,
      workingDirectory: projectRoot.path,
    );

    final doneCompleter = Completer<void>();

    flutterProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      final isNoisy = trimmed.isEmpty ||
          trimmed == 'Flutter run key commands.' ||
          trimmed == 'h List all available interactive commands.' ||
          trimmed == 'c Clear the screen' ||
          trimmed == 'q Quit (terminate the application on the device).' ||
          trimmed == 'Application finished.' ||
          trimmed.startsWith('[recorder]') ||
          trimmed.startsWith('[IMPORTANT:flutter') ||
          trimmed.startsWith('package:media_kit') ||
          trimmed.startsWith('media_kit:') ||
          trimmed.startsWith('VideoOutput') ||
          trimmed.startsWith('NativeVideoController:') ||
          trimmed.startsWith('{handle:') ||
          RegExp(r'^\d+\s+\d+$').hasMatch(trimmed);

      if (!isNoisy) {
        stdout.writeln(line);
      }
      if (line.contains('[recorder] done')) {
        if (!doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      }
    });

    flutterProcess.stderr.listen(stderr.add);

    final checkTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final doneFile = File('${projectRoot.path}/build/captures/$t/.done');
      if (doneFile.existsSync()) {
        timer.cancel();
        if (!doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      }
    });

    doneCompleter.future.then((_) async {
      checkTimer.cancel();
      try {
        flutterProcess.stdin.writeln('q');
        await flutterProcess.stdin.flush();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1500));
      flutterProcess.kill();
    });

    final exitCode = await flutterProcess.exitCode;
    checkTimer.cancel();
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'gingaf.exe'],
            runInShell: true);
      } catch (_) {}
    }
    if (exitCode != 0 && exitCode != -1) {
      stderr.writeln(
          'Warning: Flutter process exited with code $exitCode for target $t');
    }

    if (capturesDir.existsSync()) {
      final frames = capturesDir
          .listSync()
          .where((f) => f.path.endsWith('.png'))
          .toList();

      if (frames.isNotEmpty) {
        final outGif = '${appFile.path}.gif';
        stdout.writeln('Encoding $outGif from ${frames.length} frames...');

        final targetFps = scenario.fps ?? fps;
        final filter =
            'fps=$targetFps,scale=$width:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse';

        final ffmpegResult = await Process.run(
          'ffmpeg',
          [
            '-y',
            '-framerate',
            '$targetFps',
            '-i',
            '${capturesDir.path}/frame_%04d.png',
            '-vf',
            filter,
            outGif,
          ],
          runInShell: true,
        );

        if (ffmpegResult.exitCode == 0) {
          final file = File(outGif);
          final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(2);
          stdout.writeln('Successfully generated $outGif ($sizeKb KB)');
          generatedGifs.add(file);

          final subDir =
              appFile.parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
          if (subDir != 'examples') {
            final rootGif = File('${projectRoot.path}/examples/$subDir.gif');
            try {
              file.copySync(rootGif.path);
              stdout.writeln('Also copied to ${rootGif.path}');
            } catch (_) {}
          }
        } else {
          stderr.writeln('Error encoding GIF for $t: ${ffmpegResult.stderr}');
        }
      }
    }
  }

  if (generatedGifs.isNotEmpty) {
    stdout.writeln('\nGenerated GIFs:');
    for (final file in generatedGifs) {
      final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(2);
      stdout.writeln(' - ${file.path} ($sizeKb KB)');
    }
  }
  exit(0);
}
