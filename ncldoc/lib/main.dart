import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import 'ncl_document.dart';

final _logger = Logger('ncldoc_cli');

void main(List<String> arguments) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    stdout.writeln(
      '[${record.loggerName}] ${record.level.name}: ${record.message}',
    );
  });

  if (arguments.isEmpty) {
    _logger.info(
      'Usage: dart ncldoc/lib/main.dart <file.ncl> [ticksPerSecond (default: 1)]',
    );
    exit(1);
  }

  if (!arguments[0].toLowerCase().endsWith('.ncl')) {
    _logger.severe('Error: Only .ncl files are supported.');
    exit(1);
  }

  var file = File(arguments[0]);
  if (!file.existsSync()) {
    _logger.severe('File not found: ${arguments[0]}');
    exit(1);
  }

  _logger.info('Executing ${arguments[0]} in headless mode...');

  String content = file.readAsStringSync();

  int ticksPerSecond = 1;
  if (arguments.length > 1) {
    ticksPerSecond = int.tryParse(arguments[1]) ?? 1;
  }

  var document = NCLDocument.fromXML(content, baseURI: Uri.file(arguments[0]));
  document.start();

  StreamSubscription<ProcessSignal>? sigintSub;
  StreamSubscription<List<int>>? stdinSub;

  void stopDocument() {
    document.stop();
    sigintSub?.cancel();
    stdinSub?.cancel();

    if (stdin.hasTerminal) {
      stdin.lineMode = true;
      stdin.echoMode = true;
    }
    exit(0);
  }

  sigintSub = ProcessSignal.sigint.watch().listen((ProcessSignal signal) {
    _logger.info('Captured Ctrl+C, so stopping document.');
    stopDocument();
  });

  _logger.info('Starting execution at $ticksPerSecond ticks per second...');
  _logger.info('Press Ctrl+D to quit the document...');

  try {
    if (stdin.hasTerminal) {
      stdin.echoMode = false;
      stdin.lineMode = false;
    }
    stdinSub = stdin.listen((List<int> codes) {
      if (codes.contains(4)) {
        _logger.info('Captured Ctrl+D, so stopping document.');
        stopDocument();
      }
    });
  } catch (e) {
    _logger.severe('Error: $e');
  }

  document.tickIndefinitely(
    ticksPerSecond: ticksPerSecond,
    onStop: () => exit(0),
  );
}
