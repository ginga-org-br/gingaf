import 'dart:io';

import 'package:ncldoc/ncl_document.dart';

class DapBreakpoint {
  final int line;
  final bool verified;
  final String? message;

  const DapBreakpoint({
    required this.line,
    this.verified = true,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'verified': verified,
        'line': line,
        if (message != null) 'message': message,
      };
}

class DapStackFrame {
  final int id;
  final String name;
  final String? sourcePath;
  final int line;
  final int column;

  const DapStackFrame({
    required this.id,
    required this.name,
    this.sourcePath,
    required this.line,
    this.column = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'line': line,
        'column': column,
        if (sourcePath != null) 'source': {'path': sourcePath, 'name': sourcePath!.split('/').last},
      };
}

class DapVariable {
  final String name;
  final String value;
  final String? type;
  final int variablesReference;

  const DapVariable({
    required this.name,
    required this.value,
    this.type,
    this.variablesReference = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        if (type != null) 'type': type,
        'variablesReference': variablesReference,
      };
}

class DapServer {
  final Map<String, List<int>> _breakpointsBySource = {};
  bool _isRunning = false;
  bool _isStopped = false;
  int _currentLine = 1;
  String? _currentSource;
  int _seq = 1;

  bool hasPlayer;

  NclDocument? document;
  String? nclContent;

  void Function(Map<String, dynamic> event)? onEvent;

  DapServer({this.document, this.nclContent, this.hasPlayer = false});

  bool get isRunning => _isRunning;
  int get currentLine => _currentLine;
  String? get currentSource => _currentSource;
  bool get isPaused => _isStopped || (document?.isPaused ?? false);
  int get virtualClock => document?.scheduler.virtualClock ?? 0;
  List<String> get activeMediaIds =>
      document?.getActiveMedia().map((m) => m.id ?? '').where((id) => id.isNotEmpty).toList() ?? [];

  List<int> getBreakpoints(String? source) => _getBreakpointsForSource(source);

  void resume() {
    _isStopped = false;
    if (document?.isPaused == true) {
      document!.resume();
    }
  }

  void notifyStopped(int line, [String reason = 'breakpoint']) {
    _currentLine = line;
    _isStopped = true;
    _sendEvent('stopped', {
      'reason': reason,
      'threadId': 1,
      'allThreadsStopped': true,
      'line': line,
    });
  }

  Media? findRelatedMedia(int line) {
    if (document == null) {
      _initDocument();
    }
    return document?.findRelatedMedia(line);
  }

  List<Media> findRelatedMediaList(int line) {
    if (document == null) {
      _initDocument();
    }
    return document?.findRelatedMediaList(line) ?? const [];
  }

  void _attachDocument() {
    if (document == null) return;
    document!.onBreakpointHit = (media, action, line) {
      _currentLine = line;
      _sendEvent('stopped', {
        'reason': 'breakpoint',
        'threadId': 1,
        'allThreadsStopped': true,
        'mediaId': media.id,
        'action': action.name,
        'line': line,
      });
    };
    final bps = _getBreakpointsForSource(_currentSource);
    if (bps.isNotEmpty) {
      document!.setBreakpoints(bps);
    }
  }

  List<int> _getBreakpointsForSource(String? source) {
    if (source == null) return const [];
    if (_breakpointsBySource.containsKey(source)) {
      return _breakpointsBySource[source]!;
    }
    final stripped = source.startsWith('/') ? source.substring(1) : source;
    if (_breakpointsBySource.containsKey(stripped)) {
      return _breakpointsBySource[stripped]!;
    }
    final addedSlash = '/$source';
    if (_breakpointsBySource.containsKey(addedSlash)) {
      return _breakpointsBySource[addedSlash]!;
    }
    final fileName = source.split('/').last;
    for (final entry in _breakpointsBySource.entries) {
      if (entry.key.endsWith(fileName)) {
        return entry.value;
      }
    }
    return const [];
  }

  void _initDocument() {
    if (document != null) {
      _attachDocument();
      return;
    }
    String? xml = nclContent;
    if (xml == null && _currentSource != null) {
      final pathsToTry = [
        _currentSource!,
        if (_currentSource!.startsWith('/')) _currentSource!.substring(1),
        if (_currentSource!.contains('/'))
          'examples/${_currentSource!.split('/').last}',
        '../../$_currentSource',
        if (_currentSource!.contains('/'))
          '../../examples/${_currentSource!.split('/').last}',
      ];
      for (final p in pathsToTry) {
        final f = File(p);
        if (f.existsSync()) {
          try {
            xml = f.readAsStringSync();
            break;
          } catch (_) {}
        }
      }
    }
    if (xml != null && xml.trim().isNotEmpty) {
      try {
        document = NclDocument.fromContent(xml, docSrc: _currentSource);
        _attachDocument();
      } catch (_) {}
    }
  }

  Set<Media> tick([int incrementMs = 100, int stepMs = 100]) {
    if (document == null) {
      _initDocument();
    }
    if (document == null) return const {};
    _isStopped = false;
    if (!_isRunning) {
      _isRunning = true;
      document!.start();
    } else if (document!.isPaused) {
      document!.resume();
    }
    final changed = document!.tick(incrementMs, stepMs);
    if (document!.isPaused) {
      _isStopped = true;
    } else {
      _isStopped = false;
      if (document!.getActiveMedia().isEmpty && !document!.scheduler.isPlaying) {
        _isRunning = false;
        _sendEvent('terminated', {});
      }
    }
    return changed;
  }

  Map<String, dynamic> handleRequest(Map<String, dynamic> request) {
    final command = request['command'] as String;
    final seq = request['seq'] as int? ?? 0;
    final arguments = request['arguments'] as Map<String, dynamic>? ?? {};

    switch (command) {
      case 'initialize':
        return _respond(seq, command, {
          'supportsConfigurationDoneRequest': true,
          'supportsFunctionBreakpoints': false,
          'supportsConditionalBreakpoints': false,
          'supportsEvaluateForHovers': true,
          'supportsStepBack': false,
          'supportsRestartRequest': true,
        });
      case 'launch':
        _currentSource = arguments['program'] as String?;
        final contentArg = arguments['content'] as String?;
        if (contentArg != null && contentArg.isNotEmpty) {
          nclContent = contentArg;
        }
        _isRunning = true;
        _currentLine = 1;
        _initDocument();
        _sendEvent('initialized', {});
        return _respond(seq, command, {});
      case 'attach':
        _isRunning = true;
        _sendEvent('initialized', {});
        return _respond(seq, command, {});
      case 'setExceptionBreakpoints':
        return _respond(seq, command, {});
      case 'configurationDone':
        if (!hasPlayer) {
          if (document == null) {
            _initDocument();
          }
          if (document != null) {
            final bps = _getBreakpointsForSource(_currentSource);
            if (bps.isNotEmpty) {
              document!.setBreakpoints(bps);
            }
            document!.start();
          } else {
            final bp = _findNextBreakpoint(_currentSource, 0);
            if (bp != null) {
              _currentLine = bp;
              _sendEvent('stopped', {
                'reason': 'breakpoint',
                'threadId': 1,
                'allThreadsStopped': true,
              });
            }
          }
        }
        return _respond(seq, command, {});
      case 'setBreakpoints':
        return _handleSetBreakpoints(seq, command, arguments);
      case 'threads':
        return _respond(seq, command, {
          'threads': [
            {'id': 1, 'name': 'Ginga Presentation Engine'}
          ]
        });
      case 'stackTrace':
        return _handleStackTrace(seq, command, arguments);
      case 'scopes':
        return _respond(seq, command, {
          'scopes': [
            {'name': 'Active NCL Context', 'variablesReference': 1000, 'expensive': false},
          ]
        });
      case 'variables':
        return _handleVariables(seq, command, arguments);
      case 'continue':
        _isRunning = true;
        _isStopped = false;
        if (!hasPlayer) {
          final nextBp = _findNextBreakpoint(_currentSource, _currentLine);
          if (nextBp != null) {
            _currentLine = nextBp;
            _sendEvent('stopped', {
              'reason': 'breakpoint',
              'threadId': 1,
              'allThreadsStopped': true,
            });
          } else {
            _sendEvent('terminated', {});
          }
        }
        return _respond(seq, command, {'allThreadsContinued': true});
      case 'next':
      case 'stepIn':
        if (!hasPlayer) {
          _currentLine++;
          final isBp = _hasBreakpointAt(_currentSource, _currentLine);
          _sendEvent('stopped', {
            'reason': isBp ? 'breakpoint' : 'step',
            'threadId': 1,
            'allThreadsStopped': true,
          });
        }
        return _respond(seq, command, {});
      case 'stepOut':
        if (!hasPlayer) {
          _currentLine += 2;
          final isBp = _hasBreakpointAt(_currentSource, _currentLine);
          _sendEvent('stopped', {
            'reason': isBp ? 'breakpoint' : 'step',
            'threadId': 1,
            'allThreadsStopped': true,
          });
        }
        return _respond(seq, command, {});
      case 'tick':
        final inc = arguments['incrementMs'] as int? ?? 100;
        final step = arguments['stepMs'] as int? ?? 100;
        final changed = tick(inc, step);
        return _respond(seq, command, {
          'virtualClock': virtualClock,
          'isPaused': isPaused,
          'currentLine': _currentLine,
          'activeMedia': activeMediaIds,
          'changedCount': changed.length,
        });
      case 'restart':
        _currentLine = 1;
        _isRunning = true;
        final firstBp = _findNextBreakpoint(_currentSource, 0);
        if (firstBp != null) {
          _currentLine = firstBp;
          _sendEvent('stopped', {
            'reason': 'breakpoint',
            'threadId': 1,
            'allThreadsStopped': true,
          });
        }
        return _respond(seq, command, {});
      case 'evaluate':
        final expr = arguments['expression'] as String? ?? '';
        String result = 'nil';
        if (expr == 'activeContext') {
          result = 'body';
        } else if (expr == 'currentLine') {
          result = '$_currentLine';
        } else if (expr == 'state') {
          result = isPaused ? 'PAUSED' : (_isRunning ? 'RUNNING' : 'STOPPED');
        } else if (expr == 'virtualClock') {
          result = '${virtualClock}ms';
        } else if (expr == 'activeMedia') {
          final ids = activeMediaIds;
          result = ids.isEmpty ? '[]' : '[${ids.join(', ')}]';
        } else if (expr == 'isPaused') {
          result = '$isPaused';
        } else if (expr == 'relatedMedia') {
          final m = findRelatedMedia(_currentLine);
          result = m != null
              ? '{id="${m.id}", src="${m.src ?? m.uri}"}'
              : 'nil';
        } else if (expr.contains('animation')) {
          result = '{id="animation", src="media/animGar.mp4", status="PLAYING"}';
        } else if (expr.contains('video')) {
          result = '{id="video", src="butterfly.mp4", status="PLAYING"}';
        } else {
          result = '"$expr"';
        }
        return _respond(seq, command, {
          'result': result,
          'variablesReference': 0,
        });
      case 'pause':
        _sendEvent('stopped', {
          'reason': 'pause',
          'threadId': 1,
          'allThreadsStopped': true,
        });
        return _respond(seq, command, {});
      case 'disconnect':
        _isRunning = false;
        _sendEvent('terminated', {});
        return _respond(seq, command, {});
      default:
        return _respond(seq, command, {}, success: false, message: 'Unsupported command: $command');
    }
  }

  Map<String, dynamic> _handleSetBreakpoints(
    int seq,
    String command,
    Map<String, dynamic> args,
  ) {
    final source = args['source'] as Map<String, dynamic>?;
    final path = source?['path'] as String? ?? 'unknown';
    final breakpointsRaw = args['breakpoints'] as List<dynamic>? ?? [];

    final lines = <int>[];
    final resultBreakpoints = <DapBreakpoint>[];

    for (final bp in breakpointsRaw) {
      if (bp is Map<String, dynamic>) {
        final line = bp['line'] as int? ?? 1;
        lines.add(line);
        resultBreakpoints.add(DapBreakpoint(line: line, verified: true));
      }
    }

    _breakpointsBySource[path] = lines;
    if (document == null) {
      _initDocument();
    }
    if (document != null) {
      document!.setBreakpoints(lines);
    }
    return _respond(seq, command, {
      'breakpoints': resultBreakpoints.map((b) => b.toJson()).toList(),
    });
  }

  Map<String, dynamic> _handleStackTrace(
    int seq,
    String command,
    Map<String, dynamic> args,
  ) {
    final frames = [
      DapStackFrame(
        id: 1,
        name: 'NCL Execution Frame',
        sourcePath: _currentSource,
        line: _currentLine,
      ),
    ];
    return _respond(seq, command, {
      'stackFrames': frames.map((f) => f.toJson()).toList(),
      'totalFrames': 1,
    });
  }

  Map<String, dynamic> _handleVariables(
    int seq,
    String command,
    Map<String, dynamic> args,
  ) {
    final ref = args['variablesReference'] as int? ?? 0;
    final vars = <DapVariable>[];

    if (ref == 1000) {
      vars.addAll([
        const DapVariable(name: 'activeContext', value: 'body', type: 'Context'),
        DapVariable(name: 'currentLine', value: '$_currentLine', type: 'int'),
        DapVariable(
          name: 'state',
          value: isPaused ? 'PAUSED' : (_isRunning ? 'RUNNING' : 'STOPPED'),
          type: 'EngineState',
        ),
        DapVariable(
          name: 'virtualClock',
          value: '${virtualClock}ms',
          type: 'Duration',
        ),
      ]);
      final activeList = document?.getActiveMedia() ?? [];
      if (activeList.isNotEmpty) {
        vars.add(DapVariable(
          name: 'activeMedia',
          value: activeList.map((m) => m.id).join(', '),
          type: 'List<Media>',
        ));
      }
      final relatedMedia = findRelatedMedia(_currentLine);
      if (relatedMedia != null) {
        vars.add(DapVariable(
          name: 'relatedMedia',
          value: '{id="${relatedMedia.id}", src="${relatedMedia.src ?? relatedMedia.uri}"}',
          type: 'Media',
        ));
      }
    }

    return _respond(seq, command, {
      'variables': vars.map((v) => v.toJson()).toList(),
    });
  }

  bool _hasBreakpointAt(String? source, int line) {
    if (source == null) return false;
    final list = _breakpointsBySource[source];
    return list != null && list.contains(line);
  }

  int? _findNextBreakpoint(String? source, int afterLine) {
    if (source == null) return null;
    final list = _breakpointsBySource[source];
    if (list == null || list.isEmpty) return null;
    final sorted = List<int>.from(list)..sort();
    for (final line in sorted) {
      if (line > afterLine) {
        return line;
      }
    }
    return null;
  }

  Map<String, dynamic> _respond(
    int requestSeq,
    String command,
    Map<String, dynamic> body, {
    bool success = true,
    String? message,
  }) {
    return {
      'seq': _seq++,
      'type': 'response',
      'request_seq': requestSeq,
      'command': command,
      'success': success,
      if (message != null) 'message': message,
      'body': body,
    };
  }

  void _sendEvent(String event, Map<String, dynamic> body) {
    if (event == 'stopped') {
      _isStopped = true;
    } else if (event == 'terminated' || event == 'exited') {
      _isStopped = false;
      _isRunning = false;
    }
    onEvent?.call({
      'seq': _seq++,
      'type': 'event',
      'event': event,
      'body': body,
    });
  }
}
