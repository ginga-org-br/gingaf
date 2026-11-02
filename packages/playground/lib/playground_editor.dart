import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ncldoc/ncl_document.dart';

import 'monaco_bridge.dart';
import 'playground_catalog.dart';
import 'syntax_highlighter.dart';

const String _debugContinueSvg = '''
<svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" fill="#75BEFF">
  <path fill="#75BEFF" d="M3.5 2.75V13.25C3.5 13.664 3.164 14 2.75 14C2.336 14 2 13.664 2 13.25V2.75C2 2.336 2.336 2 2.75 2C3.164 2 3.5 2.336 3.5 2.75Z M14.578 7.149L7.578 2.186C7.397 2.058 7.198 2 7.003 2C6.484 2 6 2.411 6 3.002V13.003C6 13.594 6.485 14.005 7.004 14.005C7.201 14.005 7.403 13.946 7.585 13.815L14.585 8.777C15.142 8.376 15.139 7.546 14.579 7.15L14.578 7.149Z"/>
</svg>''';

class PlaygroundTextEditingController extends TextEditingController {
  Set<int> highlightedMediaLines = {};
  int? currentDebugLine;
  String language;

  PlaygroundTextEditingController({
    super.text,
    this.language = 'ncl',
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ??
        const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 19.0 / 13.0,
          color: Color(0xFFD4D4D4),
        );

    final rawText = text;
    final lines = rawText.split('\n');
    final lineSpans = <TextSpan>[];

    final highlightedTokens = SyntaxHighlighter.highlight(
      rawText,
      language: language,
      baseStyle: baseStyle,
    );

    final tokensByLine = <int, List<TextSpan>>{};
    var currentLine = 1;
    for (final token in highlightedTokens) {
      final t = token.text ?? '';
      if (!t.contains('\n')) {
        tokensByLine.putIfAbsent(currentLine, () => []).add(token);
      } else {
        final parts = t.split('\n');
        for (var p = 0; p < parts.length; p++) {
          if (parts[p].isNotEmpty) {
            tokensByLine.putIfAbsent(currentLine, () => []).add(
              TextSpan(text: parts[p], style: token.style),
            );
          }
          if (p < parts.length - 1) {
            currentLine++;
          }
        }
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final lineNum = i + 1;
      final isCurrent = lineNum == currentDebugLine;
      final isMediaLine = highlightedMediaLines.contains(lineNum);

      TextStyle lineStyle = baseStyle;
      if (isCurrent) {
        lineStyle = lineStyle.copyWith(
          backgroundColor: const Color(0x66FFC107),
          color: Colors.white,
          fontWeight: FontWeight.bold,
        );
      } else if (isMediaLine) {
        lineStyle = lineStyle.copyWith(
          backgroundColor: const Color(0x33FFC107),
          color: const Color(0xFFFFF9C4),
        );
      }

      final children = tokensByLine[lineNum] ??
          [TextSpan(text: lines[i], style: lineStyle)];

      lineSpans.add(TextSpan(
        style: lineStyle,
        children: children,
      ));
      if (i < lines.length - 1) {
        lineSpans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return TextSpan(children: lineSpans, style: baseStyle);
  }
}

typedef FlutterMonaco = PlaygroundEditor;
typedef FlutterMonacoState = PlaygroundEditorState;
typedef FlutterMonacoWidget = PlaygroundEditor;
typedef MonacoEditor = PlaygroundEditor;

class PlaygroundEditor extends StatefulWidget {
  final String? content;
  final String? initialContent;
  final String? filePath;
  final GingaCC? gingacc;
  final ValueChanged<String>? onContentChanged;
  final VoidCallback? onReload;
  final VoidCallback? onRun;
  final VoidCallback? onStop;
  final VoidCallback? onNext;
  final VoidCallback? onContinue;
  final VoidCallback? onDebug;
  final bool? isRunning;
  final bool readOnly;
  final List<int>? initialBreakpoints;
  final ValueChanged<List<int>>? onBreakpointsChanged;
  final bool enableDebugging;
  final bool? hasPlayer;
  final bool? showCatalogSelector;
  final List<CatalogExample>? catalogExamples;
  final ValueChanged<String>? onCatalogExampleSelected;

  const PlaygroundEditor({
    super.key,
    this.content,
    this.initialContent,
    this.filePath,
    this.gingacc,
    this.onContentChanged,
    this.onReload,
    this.onRun,
    this.onStop,
    this.onNext,
    this.onContinue,
    this.onDebug,
    this.isRunning,
    this.readOnly = false,
    this.initialBreakpoints,
    this.onBreakpointsChanged,
    this.enableDebugging = true,
    this.hasPlayer,
    this.showCatalogSelector,
    this.catalogExamples,
    this.onCatalogExampleSelected,
  });

  @override
  State<PlaygroundEditor> createState() => PlaygroundEditorState();
}

class PlaygroundEditorState extends State<PlaygroundEditor> {
  late final PlaygroundTextEditingController _controller;
  final ScrollController _gutterScrollController = ScrollController();
  final ScrollController _editorScrollController = ScrollController();
  static const double _editorLineHeight = 20.0;
  static const double _editorTopPadding = 6.0;
  MonacoBridge? _bridge;
  StreamSubscription? _diagSub;
  StreamSubscription? _dapSub;
  List<dynamic> _diagnostics = [];
  final Set<int> _breakpoints = {};
  Set<int> _highlightedMediaLines = {};
  int? _currentDebugLine;
  bool _isDebugging = false;
  bool _isPaused = false;
  int _virtualClock = 0;
  int _cursorLine = 1;
  int _cursorColumn = 1;
  bool _internalRunning = false;
  List<CatalogExample> _catalogExamples = [];
  String? _selectedExample;
  String? _currentFilePath;
  bool _isLoadingExample = false;
  List<String> _editableFiles = [];
  String? _activeFilePath;
  final Map<String, String> _fileContents = {};
  final Map<String, Set<int>> _fileBreakpoints = {};

  bool get effectiveShowCatalogSelector =>
      widget.showCatalogSelector ??
      (widget.filePath == null || widget.filePath!.isEmpty);

  String get effectiveActiveFilePath =>
      _activeFilePath ?? effectiveFilePath;

  String get effectiveFilePath =>
      _activeFilePath ?? _currentFilePath ?? widget.filePath ?? 'main.ncl';

  String get effectiveContent {
    if (_activeFilePath != null && _fileContents.containsKey(_activeFilePath)) {
      return _fileContents[_activeFilePath]!;
    }
    if (widget.content != null && widget.content!.isNotEmpty) {
      return widget.content!;
    }
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      return widget.initialContent!;
    }
    try {
      return _controller.text;
    } catch (_) {
      return '';
    }
  }

  String get documentUri =>
      'inmemory://$effectiveActiveFilePath';

  MonacoBridge? get bridge => _bridge;
  List<dynamic> get diagnostics => List.unmodifiable(_diagnostics);
  Set<int> get breakpoints => Set.unmodifiable(_breakpoints);
  Set<int> get highlightedMediaLines => Set.unmodifiable(_highlightedMediaLines);
  int? get currentDebugLine => _currentDebugLine;
  bool get isDebugging => _isDebugging;
  bool get isPaused => _isPaused;
  int get virtualClock => _virtualClock;
  List<CatalogExample> get catalogExamples => List.unmodifiable(_catalogExamples);
  String? get selectedExample => _selectedExample;
  List<String> get editableFiles => List.unmodifiable(_editableFiles);
  String get activeFilePath => effectiveActiveFilePath;
  Map<String, String> get allFileContents {
    if (effectiveActiveFilePath.isNotEmpty) {
      _fileContents[effectiveActiveFilePath] = _controller.text;
    }
    return Map.unmodifiable(_fileContents);
  }

  bool get isHtmlApplication {
    final lower = effectiveActiveFilePath.toLowerCase().split('?').first;
    return lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.xhtml');
  }

  bool get isNclApplication {
    final lower = effectiveActiveFilePath.toLowerCase().split('?').first;
    return lower.endsWith('.ncl');
  }

  String get currentLanguageId {
    final path = effectiveActiveFilePath.toLowerCase().split('?').first;
    if (path.endsWith('.ncl')) return 'ncl';
    if (path.endsWith('.lua')) return 'lua';
    if (path.endsWith('.json')) return 'json';
    if (path.endsWith('.html') || path.endsWith('.htm') || path.endsWith('.xhtml')) {
      return 'html';
    }
    return 'text';
  }

  String get languageDisplayName {
    final path = effectiveActiveFilePath.toLowerCase().split('?').first;
    if (path.endsWith('.ncl')) return 'NCL';
    if (path.endsWith('.lua')) return 'Lua';
    if (path.endsWith('.json')) return 'JSON';
    if (path.endsWith('.html') || path.endsWith('.htm') || path.endsWith('.xhtml')) {
      return 'HTML';
    }
    if (path.contains('.')) {
      return path.split('.').last.toUpperCase();
    }
    return 'Text';
  }

  bool get effectiveHasPlayer =>
      widget.hasPlayer ?? (widget.onContinue != null);

  bool get effectiveIsRunning =>
      widget.isRunning ?? (_internalRunning || _isDebugging);
  bool get canRun => !effectiveIsRunning && !_isDebugging;
  bool get canDebug =>
      widget.enableDebugging &&
      !isHtmlApplication &&
      !effectiveIsRunning &&
      !_isDebugging;
  bool get canStop => effectiveIsRunning || _isDebugging;

  List<String> _computeEditableFiles(String mainFile, List<String> otherFiles) {
    final files = <String>[mainFile];
    final slashIdx = mainFile.lastIndexOf('/');
    final dir = slashIdx != -1 ? mainFile.substring(0, slashIdx) : '';
    for (final other in otherFiles) {
      final trimmed = other.trim();
      if (trimmed.isEmpty) continue;
      final resolved = (dir.isNotEmpty && !trimmed.contains('/'))
          ? '$dir/$trimmed'
          : trimmed;
      if (!files.contains(resolved)) {
        files.add(resolved);
      }
    }
    return files;
  }

  void _updateMediaHighlight(int? line) {
    if (line == null) {
      _highlightedMediaLines = {};
      _controller.highlightedMediaLines = {};
      _controller.currentDebugLine = null;
      return;
    }

    final lines = <int>{};
    Media? media;
    try {
      media = _bridge?.findRelatedMedia(documentUri, line) ??
          _bridge?.findRelatedMedia(line);
    } catch (_) {}

    if (media != null && media.line != null) {
      final start = media.line!;
      final end = media.endLine ?? media.line!;
      for (int i = start; i <= end; i++) {
        lines.add(i);
      }
    } else {
      final textLines = _controller.text.split('\n');
      if (line >= 1 && line <= textLines.length) {
        int start = line;
        while (start >= 1) {
          final lText = textLines[start - 1];
          if (lText.contains('<media')) {
            break;
          }
          if (lText.contains('</media>') && start < line) {
            break;
          }
          start--;
        }
        if (start >= 1 && textLines[start - 1].contains('<media')) {
          int end = start;
          if (textLines[start - 1].contains('/>')) {
            end = start;
          } else {
            while (end <= textLines.length) {
              final lText = textLines[end - 1];
              if (lText.contains('</media>')) {
                break;
              }
              end++;
            }
          }
          if (end <= textLines.length && line >= start && line <= end) {
            for (int i = start; i <= end; i++) {
              lines.add(i);
            }
          }
        }
      }
    }

    _highlightedMediaLines = lines;
    _controller.highlightedMediaLines = lines;
    _controller.currentDebugLine = line;
  }

  @override
  void initState() {
    super.initState();
    _currentFilePath = widget.filePath;
    _selectedExample = widget.filePath;
    if (widget.filePath != null && widget.filePath!.isNotEmpty) {
      _activeFilePath = widget.filePath;
      _editableFiles = [widget.filePath!];
      if (effectiveContent.isNotEmpty) {
        _fileContents[widget.filePath!] = effectiveContent;
      }
    }
    if (isNclApplication && widget.initialBreakpoints != null) {
      _breakpoints.addAll(widget.initialBreakpoints!);
      if (_activeFilePath != null) {
        _fileBreakpoints[_activeFilePath!] = Set<int>.from(_breakpoints);
      }
    }
    _controller = PlaygroundTextEditingController(
      text: effectiveContent,
      language: currentLanguageId,
    );
    _controller.addListener(_handleTextControllerChange);
    _editorScrollController.addListener(() {
      if (_gutterScrollController.hasClients &&
          (_gutterScrollController.offset - _editorScrollController.offset).abs() > 0.5) {
        _gutterScrollController.jumpTo(_editorScrollController.offset);
      }
    });
    _gutterScrollController.addListener(() {
      if (_editorScrollController.hasClients &&
          (_editorScrollController.offset - _gutterScrollController.offset).abs() > 0.5) {
        _editorScrollController.jumpTo(_gutterScrollController.offset);
      }
    });

    if (widget.catalogExamples != null && widget.catalogExamples!.isNotEmpty) {
      _catalogExamples = widget.catalogExamples!;
      _matchSelectedExample();
    } else if (effectiveShowCatalogSelector) {
      _initCatalog();
    } else if (_controller.text.isEmpty &&
        widget.filePath != null &&
        widget.filePath!.isNotEmpty) {
      _loadStandaloneFile(widget.filePath!);
    }

    try {
      _bridge = MonacoBridge();
      _bridge?.hasPlayer = effectiveHasPlayer;
      _diagSub = _bridge?.diagnosticsStream.listen((event) {
        if (mounted) {
          setState(() {
            _diagnostics = (event['diagnostics'] as List<dynamic>?) ?? [];
          });
        }
      });
      _dapSub = _bridge?.dapEventsStream.listen((event) {
        if (mounted) {
          setState(() {
            if (event['event'] == 'stopped') {
              _isPaused = true;
              _currentDebugLine = _bridge?.currentDebugLine ?? (event['body']?['line'] as int?);
              _updateMediaHighlight(_currentDebugLine);
            } else if (event['event'] == 'terminated') {
              if (widget.isRunning != true) {
                _isDebugging = false;
                _internalRunning = false;
                _isPaused = false;
                _currentDebugLine = null;
                _updateMediaHighlight(null);
              }
            }
            _virtualClock = _bridge?.virtualClock ?? 0;
          });
        }
      });
      _bridge?.openDocument(documentUri, effectiveContent);
      if (_breakpoints.isNotEmpty) {
        _bridge?.setBreakpoints(documentUri, _breakpoints.toList());
      }
    } catch (_) {}
  }

  Future<void> _initCatalog() async {
    final examples = await loadCatalogExamples(gingacc: widget.gingacc);
    if (mounted) {
      setState(() {
        _catalogExamples = examples;
        _matchSelectedExample();
      });
      if (_catalogExamples.isNotEmpty && _controller.text.isEmpty) {
        final targetExample =
            _selectedExample ?? _catalogExamples.first.mainFile;
        selectCatalogExample(targetExample);
      }
    }
  }

  Future<void> _loadStandaloneFile(String path) async {
    final cc = widget.gingacc ?? GingaCC();
    try {
      final loaded = await cc.loadContent(path);
      if (loaded != null && loaded.isNotEmpty && mounted && _controller.text.isEmpty) {
        setState(() {
          _controller.text = loaded;
        });
        _bridge?.openDocument(documentUri, loaded);
        widget.onContentChanged?.call(loaded);
      }
    } catch (_) {}
  }

  void _matchSelectedExample() {
    if (_catalogExamples.isEmpty) return;
    if (_selectedExample != null) {
      final exists = _catalogExamples.any((e) =>
          e.mainFile == _selectedExample ||
          'examples/${e.mainFile}' == _selectedExample ||
          e.key == _selectedExample);
      if (exists) {
        final found = _catalogExamples.firstWhere((e) =>
            e.mainFile == _selectedExample ||
            'examples/${e.mainFile}' == _selectedExample ||
            e.key == _selectedExample);
        _selectedExample = found.mainFile;
        _editableFiles =
            _computeEditableFiles(found.mainFile, found.otherEditableFiles);
        _activeFilePath ??= found.mainFile;
        _currentFilePath ??= found.mainFile;
      }
    }
  }

  Future<void> selectCatalogExample(String mainFile) async {
    CatalogExample? example;
    for (final e in _catalogExamples) {
      if (e.mainFile == mainFile ||
          e.key == mainFile ||
          'examples/${e.mainFile}' == mainFile) {
        example = e;
        break;
      }
    }

    final otherFiles = example?.otherEditableFiles ?? const <String>[];
    final files = _computeEditableFiles(mainFile, otherFiles);

    setState(() {
      _selectedExample = mainFile;
      _currentFilePath = mainFile;
      _activeFilePath = mainFile;
      _editableFiles = files;
      _isLoadingExample = true;
      _breakpoints.clear();
    });

    final loaded = await loadExampleContent(mainFile, gingacc: widget.gingacc);
    if (loaded != null) {
      _fileContents[mainFile] = loaded;
      _controller.text = loaded;
      _bridge?.openDocument('inmemory://$mainFile', loaded);
      widget.onContentChanged?.call(loaded);
      widget.onCatalogExampleSelected?.call(mainFile);
    }

    for (final other in files) {
      if (other != mainFile && !_fileContents.containsKey(other)) {
        loadExampleContent(other, gingacc: widget.gingacc).then((res) {
          if (res != null && mounted) {
            _fileContents[other] = res;
          }
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingExample = false;
      });
    }
  }

  Future<void> switchToFile(String targetFile) async {
    if (targetFile == _activeFilePath) return;

    final previousFile = effectiveActiveFilePath;
    _fileContents[previousFile] = _controller.text;
    if (previousFile.endsWith('.ncl')) {
      _fileBreakpoints[previousFile] = Set<int>.from(_breakpoints);
    }

    _activeFilePath = targetFile;
    _currentFilePath = targetFile;
    _controller.language = currentLanguageId;

    String? content = _fileContents[targetFile];
    if (content == null) {
      _isLoadingExample = true;
      if (mounted) setState(() {});
      content = await loadExampleContent(targetFile, gingacc: widget.gingacc);
      if (content == null && widget.gingacc != null) {
        try {
          content = await widget.gingacc!.loadContent(targetFile);
        } catch (_) {}
      }
      content ??= '';
      _fileContents[targetFile] = content;
      _isLoadingExample = false;
    }

    _controller.text = content;
    _bridge?.openDocument(documentUri, content);

    if (isNclApplication) {
      _breakpoints.clear();
      final saved = _fileBreakpoints[targetFile];
      if (saved != null) {
        _breakpoints.addAll(saved);
      }
      _bridge?.setBreakpoints(documentUri, _breakpoints.toList()..sort());
      widget.onBreakpointsChanged?.call(_breakpoints.toList()..sort());
    } else {
      _breakpoints.clear();
      _bridge?.setBreakpoints(documentUri, []);
      widget.onBreakpointsChanged?.call([]);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant PlaygroundEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.catalogExamples != null &&
        widget.catalogExamples != oldWidget.catalogExamples) {
      _catalogExamples = widget.catalogExamples!;
      _matchSelectedExample();
    }
    if (widget.filePath != oldWidget.filePath && widget.filePath != null) {
      _currentFilePath = widget.filePath;
      _selectedExample = widget.filePath;
      _activeFilePath = widget.filePath;
      _editableFiles = [widget.filePath!];
      _matchSelectedExample();
    }
    if (_controller.language != currentLanguageId) {
      _controller.language = currentLanguageId;
    }
    _bridge?.hasPlayer = effectiveHasPlayer;
    final newText = effectiveContent;
    if (newText.isNotEmpty && newText != _controller.text) {
      _controller.text = newText;
      _fileContents[effectiveActiveFilePath] = newText;
      _bridge?.updateDocument(documentUri, newText);
      if (_currentDebugLine != null) {
        _updateMediaHighlight(_currentDebugLine);
      }
    }
  }

  void toggleBreakpoint(int line) {
    if (!isNclApplication) return;
    if (_breakpoints.contains(line)) {
      _breakpoints.remove(line);
    } else {
      _breakpoints.add(line);
    }
    _fileBreakpoints[effectiveActiveFilePath] = Set<int>.from(_breakpoints);
    _bridge?.setBreakpoints(documentUri, _breakpoints.toList()..sort());
    widget.onBreakpointsChanged?.call(_breakpoints.toList()..sort());
    if (mounted) setState(() {});
  }

  void setBreakpoints(Iterable<int> lines) {
    if (!isNclApplication) {
      _breakpoints.clear();
      _fileBreakpoints[effectiveActiveFilePath] = {};
      _bridge?.setBreakpoints(documentUri, []);
      widget.onBreakpointsChanged?.call([]);
      if (mounted) setState(() {});
      return;
    }
    _breakpoints
      ..clear()
      ..addAll(lines);
    _fileBreakpoints[effectiveActiveFilePath] = Set<int>.from(_breakpoints);
    _bridge?.setBreakpoints(documentUri, _breakpoints.toList()..sort());
    widget.onBreakpointsChanged?.call(_breakpoints.toList()..sort());
    if (mounted) setState(() {});
  }

  void pauseAtLine(int line) {
    _isDebugging = true;
    _isPaused = true;
    _currentDebugLine = line;
    _updateMediaHighlight(line);
    _bridge?.notifyStopped(line);
    if (mounted) setState(() {});
  }

  void startDebugging() {
    if (isHtmlApplication || _isDebugging) return;
    final bps = _breakpoints.toList()..sort();
    _bridge?.setBreakpoints(documentUri, bps);
    widget.onBreakpointsChanged?.call(bps);
    _bridge?.startDebugging(documentUri, _controller.text);
    _isDebugging = true;
    _internalRunning = true;
    if (effectiveHasPlayer) {
      _isPaused = false;
      _currentDebugLine = null;
      _updateMediaHighlight(null);
    } else {
      _isPaused = _bridge?.isPaused ?? false;
      _currentDebugLine = _bridge?.currentDebugLine;
      _updateMediaHighlight(_currentDebugLine);
    }
    _virtualClock = _bridge?.virtualClock ?? 0;
    if (mounted) setState(() {});
  }

  void continueExecution() {
    _isPaused = false;
    _currentDebugLine = null;
    _updateMediaHighlight(null);
    _bridge?.continueExecution();
    widget.onContinue?.call();
    if (mounted) setState(() {});
  }

  void resumeFromPlayer() {
    _isPaused = false;
    _currentDebugLine = null;
    _updateMediaHighlight(null);
    _bridge?.continueExecution();
    if (mounted) setState(() {});
  }

  void step([int incrementMs = 100]) {
    _bridge?.step(incrementMs);
    _isPaused = _bridge?.isPaused ?? false;
    _currentDebugLine = _bridge?.currentDebugLine;
    _updateMediaHighlight(_currentDebugLine);
    _virtualClock = _bridge?.virtualClock ?? 0;
    if (mounted) setState(() {});
  }

  void tick([int incrementMs = 1000]) {
    _bridge?.tick(incrementMs);
    _isPaused = _bridge?.isPaused ?? false;
    _currentDebugLine = _bridge?.currentDebugLine;
    _updateMediaHighlight(_currentDebugLine);
    _virtualClock = _bridge?.virtualClock ?? 0;
    if (mounted) setState(() {});
  }

  void stopDebugging() {
    _bridge?.stopDebugging();
    _isDebugging = false;
    _internalRunning = false;
    _isPaused = false;
    _currentDebugLine = null;
    _updateMediaHighlight(null);
    _virtualClock = 0;
    if (mounted) setState(() {});
  }

  void _handleRun() {
    setState(() {
      _internalRunning = true;
      _isDebugging = false;
    });
    if (widget.onRun != null) {
      widget.onRun!();
    } else if (widget.onReload != null) {
      widget.onReload!();
    }
  }

  void _handleDebug() {
    if (!canDebug) return;
    setState(() {
      _internalRunning = true;
    });
    startDebugging();
    widget.onDebug?.call();
  }

  void _handleStop() {
    if (_isDebugging) {
      stopDebugging();
    }
    setState(() {
      _internalRunning = false;
    });
    widget.onStop?.call();
  }

  void _handleTextControllerChange() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.isValid) {
      final prefix = text.substring(0, selection.baseOffset.clamp(0, text.length));
      final lines = prefix.split('\n');
      _cursorLine = lines.length;
      _cursorColumn = lines.last.length + 1;
    }
    _fileContents[effectiveActiveFilePath] = text;
    _bridge?.updateDocument(documentUri, text);
    final mainFile = _selectedExample ??
        widget.filePath ??
        (_editableFiles.isNotEmpty ? _editableFiles.first : effectiveFilePath);
    if (effectiveActiveFilePath == mainFile) {
      widget.onContentChanged?.call(text);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextControllerChange);
    _controller.dispose();
    _gutterScrollController.dispose();
    _editorScrollController.dispose();
    _diagSub?.cancel();
    _dapSub?.cancel();
    _bridge?.dispose();
    super.dispose();
  }

  int _computeVisualLines(String lineText, double availableWidth) {
    if (lineText.isEmpty || availableWidth <= 0) return 1;
    if (lineText.length * 8.5 <= availableWidth) {
      return 1;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: lineText,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: _editorLineHeight / 13.0,
        ),
      ),
      strutStyle: const StrutStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: _editorLineHeight / 13.0,
        forceStrutHeight: true,
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: availableWidth);
    final count = painter.computeLineMetrics().length;
    return count > 0 ? count : 1;
  }

  Widget _buildCatalogSelector() {
    final validSelected =
        _catalogExamples.any((e) => e.mainFile == _selectedExample)
            ? _selectedExample
            : null;

    final Map<String, List<CatalogExample>> grouped = {};
    for (final item in _catalogExamples) {
      final cat = item.category.isNotEmpty ? item.category : 'general';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    final items = <DropdownMenuItem<String>>[];
    for (final entry in grouped.entries) {
      final categoryTitle = entry.key.toUpperCase().replaceAll('_', ' ');
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '__category_${entry.key}__',
          child: Container(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              '-- $categoryTitle --',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      );
      for (final item in entry.value) {
        final label = item.description.isNotEmpty
            ? '${item.mainFile} - ${item.description}'
            : item.mainFile;
        items.add(
          DropdownMenuItem<String>(
            key: Key('catalog_option_${item.key}'),
            value: item.mainFile,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Catalog:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 28,
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3C3C3C),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF555555), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('catalog_select'),
              value: validSelected,
              isDense: true,
              isExpanded: true,
              dropdownColor: const Color(0xFF3C3C3C),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              icon: const Icon(Icons.arrow_drop_down,
                  color: Colors.white, size: 18),
              hint: Text(
                _catalogExamples.isEmpty
                    ? 'Loading catalog...'
                    : '-- Select an example from catalog --',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              items: items,
              onChanged: (val) {
                if (val != null && !val.startsWith('__category_')) {
                  selectCatalogExample(val);
                }
              },
            ),
          ),
        ),
        if (_isLoadingExample) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileTab(String filePath) {
    final isActive = filePath == effectiveActiveFilePath;
    final fileName = (filePath.contains('/') || filePath.contains('\\'))
        ? filePath.split(RegExp(r'[/\\]')).last.split('?').first
        : filePath.split('?').first;
    final fileExt = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    IconData icon;
    Color iconColor;
    if (fileExt == 'ncl') {
      icon = Icons.code;
      iconColor = const Color(0xFF60A5FA);
    } else if (fileExt == 'lua') {
      icon = Icons.terminal;
      iconColor = const Color(0xFF34D399);
    } else if (fileExt == 'json') {
      icon = Icons.data_object;
      iconColor = const Color(0xFFFBBF24);
    } else if (fileExt == 'html' || fileExt == 'htm' || fileExt == 'xhtml') {
      icon = Icons.html;
      iconColor = const Color(0xFFF87171);
    } else {
      icon = Icons.insert_drive_file;
      iconColor = const Color(0xFF94A3B8);
    }

    return Tooltip(
      message: filePath,
      child: InkWell(
        key: Key('file_tab_$fileName'),
        onTap: () => switchToFile(filePath),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E1E1E) : const Color(0xFF252526),
            border: Border(
              top: BorderSide(
                color: isActive ? const Color(0xFF007ACC) : Colors.transparent,
                width: 2,
              ),
              right: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
              bottom: BorderSide(
                color: isActive ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                fileName,
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBarWithActions() {
    return Container(
      key: const Key('playground_file_tabs_bar'),
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        border: Border(
          top: BorderSide(color: Color(0xFF2D2D2D), width: 1),
          bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _editableFiles.map(_buildFileTab).toList(),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('monaco_run_button'),
                  tooltip: 'Run',
                  icon: const Icon(Icons.play_arrow, size: 18),
                  color: const Color(0xFF4CAF50),
                  disabledColor: const Color(0xFF555555),
                  onPressed: canRun ? _handleRun : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(26, 26),
                    padding: EdgeInsets.zero,
                  ),
                ),
                if (widget.enableDebugging)
                  IconButton(
                    key: const Key('monaco_debug_start_button'),
                    tooltip: isHtmlApplication
                        ? 'Debugging not supported for HTML'
                        : 'Start Debugging',
                    icon: const Icon(Icons.bug_report, size: 16),
                    color: const Color(0xFF007ACC),
                    disabledColor: const Color(0xFF555555),
                    onPressed: canDebug ? _handleDebug : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(26, 26),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                if (_isDebugging) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: const Key('monaco_debug_controls_box'),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF454545),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('monaco_debug_continue_button'),
                          tooltip: 'Continue',
                          icon: SvgPicture.string(
                            _debugContinueSvg,
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              _isPaused ? const Color(0xFF75BEFF) : const Color(0xFF666666),
                              BlendMode.srcIn,
                            ),
                          ),
                          color: const Color(0xFF75BEFF),
                          disabledColor: const Color(0xFF666666),
                          onPressed: _isPaused ? continueExecution : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(24, 24),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        Container(
                          height: 14,
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: const Color(0xFF454545),
                        ),
                        IconButton(
                          key: const Key('monaco_stop_button'),
                          tooltip: 'Stop',
                          icon: const Icon(Icons.stop, size: 16),
                          color: Colors.redAccent,
                          disabledColor: const Color(0xFF666666),
                          onPressed: canStop ? _handleStop : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(24, 24),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (canStop) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    key: const Key('monaco_stop_button'),
                    tooltip: 'Stop',
                    icon: const Icon(Icons.stop, size: 18),
                    color: Colors.redAccent,
                    disabledColor: const Color(0xFF555555),
                    onPressed: canStop ? _handleStop : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(26, 26),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _controller.text.split('\n');
    final lineCount = lines.isEmpty ? 1 : lines.length;

    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('playground_branding_banner'),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF181818),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/favicon.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'packages/playground/assets/favicon.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error2, stackTrace2) => const Icon(
                        Icons.play_circle_filled,
                        size: 18,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'GingaPlayground (powered by gingaf)',
                    key: Key('playground_branding_title'),
                    style: TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (effectiveShowCatalogSelector) ...[
                    const SizedBox(width: 14),
                    _buildCatalogSelector(),
                  ],
                ],
              ),
            ),
          ),
          _buildTabBarWithActions(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final lines = _controller.text.split('\n');
                final availableTextWidth =
                    (constraints.maxWidth - 64 - 22 - 2).clamp(100.0, double.infinity);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64,
                      padding: const EdgeInsets.only(
                        top: _editorTopPadding,
                        right: 6,
                      ),
                      color: const Color(0xFF1E1E1E),
                      child: ListView.builder(
                        controller: _gutterScrollController,
                        itemCount: lineCount,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final lineNum = index + 1;
                          final isBp = isNclApplication && _breakpoints.contains(lineNum);
                          final isCurrentLine = _currentDebugLine == lineNum;
                          final isMediaLine = _highlightedMediaLines.contains(lineNum);
                          final lineText = index < lines.length ? lines[index] : '';
                          final visualLines = _computeVisualLines(lineText, availableTextWidth);
                          final itemHeight = visualLines * _editorLineHeight;
                          return InkWell(
                            key: Key('monaco_gutter_line_$lineNum'),
                            onTap: isNclApplication ? () => toggleBreakpoint(lineNum) : null,
                            child: Container(
                              height: itemHeight,
                              color: isCurrentLine
                                  ? const Color(0x44FFC107)
                                  : (isMediaLine ? const Color(0x22FFC107) : null),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: SizedBox(
                                  height: _editorLineHeight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (isBp)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(right: 2),
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      if (isCurrentLine)
                                        const Icon(
                                          Icons.arrow_right,
                                          size: 14,
                                          color: Colors.amberAccent,
                                        ),
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          '$lineNum',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            height: _editorLineHeight / 12.0,
                                            color: isCurrentLine
                                                ? Colors.amberAccent
                                                : (isMediaLine
                                                    ? Colors.amberAccent
                                                    : (isBp
                                                        ? Colors.redAccent
                                                        : const Color(0xFF858585))),
                                            fontWeight: (isCurrentLine || isMediaLine)
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: _editorTopPadding,
                          left: 6,
                          right: 16,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            TextField(
                              key: const Key('monaco_editor_text_field'),
                              controller: _controller,
                              scrollController: _editorScrollController,
                              readOnly: widget.readOnly,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: _editorLineHeight / 13.0,
                                color: Color(0xFFD4D4D4),
                              ),
                              strutStyle: const StrutStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: _editorLineHeight / 13.0,
                                forceStrutHeight: true,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            if (_controller.text.isEmpty &&
                                effectiveShowCatalogSelector &&
                                _selectedExample == null)
                              const IgnorePointer(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.menu_book,
                                        color: Color(0xFF444444),
                                        size: 48,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Select an example from the catalog above to view and run code',
                                        style: TextStyle(
                                          color: Color(0xFF777777),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF007ACC),
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'Monaco Editor',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ln $_cursorLine, Col $_cursorColumn',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                const SizedBox(width: 8),
                const Text(
                  'UTF-8',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Text(
                  languageDisplayName,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
