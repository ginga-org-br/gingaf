import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ncldoc/ncl_document.dart';

enum ScrollDirectionMode {
  none,
  horizontal,
  vertical,
  both;

  static ScrollDirectionMode fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'horizontal':
        return ScrollDirectionMode.horizontal;
      case 'vertical':
        return ScrollDirectionMode.vertical;
      case 'both':
        return ScrollDirectionMode.both;
      default:
        return ScrollDirectionMode.none;
    }
  }
}

enum SelectorKind { row, column, literalIndex, field }

class BindingSelector {
  final SelectorKind kind;
  final int? literalIndex;
  final String? fieldName;

  const BindingSelector.row()
      : kind = SelectorKind.row,
        literalIndex = null,
        fieldName = null;

  const BindingSelector.column()
      : kind = SelectorKind.column,
        literalIndex = null,
        fieldName = null;

  const BindingSelector.index(int index)
      : kind = SelectorKind.literalIndex,
        literalIndex = index,
        fieldName = null;

  const BindingSelector.field(String name)
      : kind = SelectorKind.field,
        literalIndex = null,
        fieldName = name;
}

class BindingExpression {
  static const int maxAllowedAstDepth = 4;
  static final RegExp _identRegex = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  final String rawSource;
  final String prefix;
  final String suffix;
  final bool isDynamic;
  final String rootIdentifier;
  final List<BindingSelector> selectors;

  const BindingExpression({
    required this.rawSource,
    this.prefix = '',
    this.suffix = '',
    required this.isDynamic,
    required this.rootIdentifier,
    required this.selectors,
  });

  int get astDepth => isDynamic ? (1 + selectors.length) : 0;

  bool get usesRow => selectors.any((s) => s.kind == SelectorKind.row);
  bool get usesColumn => selectors.any((s) => s.kind == SelectorKind.column);

  static bool isDynamicExpression(String? src) {
    if (src == null) return false;
    final trimmed = src.trim();
    final openIdx = trimmed.indexOf('{');
    final closeIdx = trimmed.lastIndexOf('}');
    return openIdx != -1 && closeIdx > openIdx;
  }

  static BindingExpression parse(String raw) {
    final trimmed = raw.trim();
    final openIdx = trimmed.indexOf('{');
    final closeIdx = trimmed.lastIndexOf('}');
    if (openIdx == -1 || closeIdx <= openIdx) {
      return BindingExpression(
        rawSource: raw,
        isDynamic: false,
        rootIdentifier: '',
        selectors: const [],
      );
    }

    final prefix = trimmed.substring(0, openIdx);
    final suffix = trimmed.substring(closeIdx + 1);
    final inner = trimmed.substring(openIdx + 1, closeIdx).trim();
    if (inner.isEmpty) {
      throw const FormatException('Empty binding expression');
    }

    if (inner.contains('(') ||
        inner.contains(')') ||
        inner.contains(';') ||
        inner.contains('..') ||
        inner.contains('function') ||
        inner.contains('os.') ||
        inner.contains('io.')) {
      throw FormatException(
        'Forbidden executable token in expression: $raw',
      );
    }

    final selectors = <BindingSelector>[];
    int pos = 0;
    while (pos < inner.length && inner[pos] != '[' && inner[pos] != '.') {
      pos++;
    }

    final root = inner.substring(0, pos).trim();
    if (!_identRegex.hasMatch(root)) {
      throw FormatException('Invalid root identifier: "$root"');
    }

    while (pos < inner.length) {
      if (inner[pos] == '[') {
        final closeBracket = inner.indexOf(']', pos + 1);
        if (closeBracket == -1) {
          throw FormatException('Unclosed bracket in: $raw');
        }
        final token = inner.substring(pos + 1, closeBracket).trim();
        if (token.contains('[') || token.contains('{')) {
          throw FormatException(
            'Nested bracket expressions are prohibited: $raw',
          );
        }
        if (token == 'row') {
          selectors.add(const BindingSelector.row());
        } else if (token == 'column' || token == 'col') {
          selectors.add(const BindingSelector.column());
        } else {
          final idx = int.tryParse(token);
          if (idx == null || idx < 0) {
            throw FormatException('Invalid index selector: "$token"');
          }
          selectors.add(BindingSelector.index(idx));
        }
        pos = closeBracket + 1;
      } else if (inner[pos] == '.') {
        pos++;
        final start = pos;
        while (pos < inner.length && inner[pos] != '[' && inner[pos] != '.') {
          pos++;
        }
        final field = inner.substring(start, pos).trim();
        if (!_identRegex.hasMatch(field)) {
          throw FormatException('Invalid field identifier: "$field"');
        }
        selectors.add(BindingSelector.field(field));
      } else {
        throw FormatException(
          'Unexpected character "${inner[pos]}" in: $raw',
        );
      }
    }

    if (1 + selectors.length > maxAllowedAstDepth) {
      throw FormatException(
        'Expression AST depth ${1 + selectors.length} exceeds limit of $maxAllowedAstDepth: $raw',
      );
    }

    return BindingExpression(
      rawSource: raw,
      prefix: prefix,
      suffix: suffix,
      isDynamic: true,
      rootIdentifier: root,
      selectors: selectors,
    );
  }

  dynamic evaluate(
    Map<String, dynamic> dataContext, {
    required int row,
    required int column,
  }) {
    if (!isDynamic) return rawSource;
    dynamic current = dataContext[rootIdentifier];
    if (current == null) return null;

    for (final selector in selectors) {
      if (current == null) return null;
      switch (selector.kind) {
        case SelectorKind.row:
          current = _indexInto(current, row);
          break;
        case SelectorKind.column:
          current = _indexInto(current, column);
          break;
        case SelectorKind.literalIndex:
          current = _indexInto(current, selector.literalIndex!);
          break;
        case SelectorKind.field:
          if (current is Map) {
            current = current[selector.fieldName];
          } else {
            return null;
          }
          break;
      }
    }
    return current;
  }

  String evaluateAsString(
    Map<String, dynamic> dataContext, {
    required int row,
    required int column,
    String fallback = '',
  }) {
    final val = evaluate(dataContext, row: row, column: column);
    if (val == null) return fallback;
    return '$prefix$val$suffix';
  }

  static dynamic _indexInto(dynamic collection, int zeroBasedIndex) {
    if (collection is List) {
      if (collection.isEmpty) return null;
      if (zeroBasedIndex >= 0 && zeroBasedIndex < collection.length) {
        return collection[zeroBasedIndex];
      }
      return null;
    }
    if (collection is Map) {
      if (collection.containsKey(zeroBasedIndex)) {
        return collection[zeroBasedIndex];
      }
      if (collection.containsKey(zeroBasedIndex + 1)) {
        return collection[zeroBasedIndex + 1];
      }
      final strZero = zeroBasedIndex.toString();
      if (collection.containsKey(strZero)) {
        return collection[strZero];
      }
      final strOne = (zeroBasedIndex + 1).toString();
      if (collection.containsKey(strOne)) {
        return collection[strOne];
      }
    }
    return null;
  }
}

class SlotDescriptor {
  final int poolSlotId;
  int boundLogicalRow = -1;
  int boundLogicalCol = -1;

  SlotDescriptor({required this.poolSlotId});

  void bind({
    required int logicalRow,
    required int logicalCol,
  }) {
    boundLogicalRow = logicalRow;
    boundLogicalCol = logicalCol;
  }
}

class SlotPool {
  final int visibleRows;
  final int visibleColumns;
  final int bufferSlots;
  late final int strideRows;
  late final int strideColumns;
  late final List<SlotDescriptor> _slots;
  int _totalReuses = 0;

  SlotPool({
    required this.visibleRows,
    required this.visibleColumns,
    this.bufferSlots = 2,
  }) {
    strideRows = math.max(1, visibleRows + 2 * bufferSlots);
    strideColumns = math.max(1, visibleColumns + 2 * bufferSlots);
    final total = strideRows * strideColumns;
    _slots = List<SlotDescriptor>.generate(
      total,
      (i) => SlotDescriptor(poolSlotId: i),
      growable: false,
    );
  }

  int get capacity => _slots.length;
  int get totalReuses => _totalReuses;

  SlotDescriptor acquireSlot(int logicalRow, int logicalCol) {
    final rIdx = ((logicalRow % strideRows) + strideRows) % strideRows;
    final cIdx = ((logicalCol % strideColumns) + strideColumns) % strideColumns;
    final poolIdx = rIdx * strideColumns + cIdx;
    final slot = _slots[poolIdx];
    if (slot.boundLogicalRow != logicalRow ||
        slot.boundLogicalCol != logicalCol) {
      if (slot.boundLogicalRow != -1) {
        _totalReuses++;
      }
    }
    return slot;
  }
}

class DataBindingLuaRuntime {
  final NCLuaRuntime? ncluaRuntime;
  late final LuaState _luaState;

  DataBindingLuaRuntime({
    NclDocument? document,
    Media? media,
    NCLuaRuntime? ncluaRuntime,
  }) : ncluaRuntime = ncluaRuntime ??
            (document != null
                ? NCLuaRuntime(
                    document: document,
                    media: media ?? Media(),
                  )
                : null) {
    if (this.ncluaRuntime != null) {
      _luaState = this.ncluaRuntime!.luaState;
    } else {
      _luaState = LuaState.newState();
      _luaState.openLibs();
    }
  }

  Map<String, dynamic> execute(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};

    final baseTop = _luaState.getTop();
    try {
      ThreadStatus loadStatus = _luaState.loadString(trimmed);
      if (loadStatus != ThreadStatus.luaOk && trimmed.startsWith('{')) {
        _luaState.setTop(baseTop);
        loadStatus = _luaState.loadString('return $trimmed');
      }
      if (loadStatus != ThreadStatus.luaOk) {
        _luaState.setTop(baseTop);
        return <String, dynamic>{};
      }

      final callStatus = _luaState.pCall(0, 1, 0);
      if (callStatus != ThreadStatus.luaOk) {
        _luaState.setTop(baseTop);
        return <String, dynamic>{};
      }

      if (_luaState.isTable(-1)) {
        final converted = NCLuaRuntime.readLuaValue(_luaState, -1);
        _luaState.pushValue(-1);
        _luaState.setGlobal('data');
        _luaState.setTop(baseTop);
        if (converted is Map<String, dynamic>) return converted;
        if (converted is Map) return Map<String, dynamic>.from(converted);
        if (converted is List) return <String, dynamic>{'items': converted};
      }

      _luaState.setTop(baseTop);
      return readGlobalData('data');
    } catch (_) {
      _luaState.setTop(baseTop);
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> readGlobalData([String globalName = 'data']) {
    final baseTop = _luaState.getTop();
    _luaState.getGlobal(globalName);
    if (_luaState.isTable(-1)) {
      final converted = NCLuaRuntime.readLuaValue(_luaState, -1);
      _luaState.setTop(baseTop);
      if (converted is Map<String, dynamic>) return converted;
      if (converted is Map) return Map<String, dynamic>.from(converted);
      if (converted is List) return <String, dynamic>{'items': converted};
    }
    _luaState.setTop(baseTop);
    return <String, dynamic>{};
  }

  Map<String, dynamic> callLuaFunction(
    String functionName, [
    List<dynamic> args = const [],
  ]) {
    final baseTop = _luaState.getTop();
    _luaState.getGlobal(functionName);
    if (!_luaState.isFunction(-1)) {
      _luaState.setTop(baseTop);
      return <String, dynamic>{};
    }
    for (final arg in args) {
      NCLuaRuntime.pushDartValue(_luaState, arg);
    }
    final status = _luaState.pCall(args.length, 1, 0);
    if (status != ThreadStatus.luaOk) {
      _luaState.setTop(baseTop);
      return <String, dynamic>{};
    }
    if (_luaState.isTable(-1)) {
      final converted = NCLuaRuntime.readLuaValue(_luaState, -1);
      _luaState.pushValue(-1);
      _luaState.setGlobal('data');
      _luaState.setTop(baseTop);
      if (converted is Map<String, dynamic>) return converted;
      if (converted is Map) return Map<String, dynamic>.from(converted);
      if (converted is List) return <String, dynamic>{'items': converted};
    }
    _luaState.setTop(baseTop);
    return readGlobalData('data');
  }

  void syncDataToLua(
    Map<String, dynamic> data, [
    String globalName = 'data',
  ]) {
    final baseTop = _luaState.getTop();
    NCLuaRuntime.pushDartValue(_luaState, data);
    _luaState.setGlobal(globalName);
    _luaState.setTop(baseTop);
  }

  void dispose() {
    ncluaRuntime?.dispose();
  }
}

class DataBindingController extends ChangeNotifier {
  final String contextId;
  final DataBindingLuaRuntime luaRuntime;
  int _visibleRows;
  int _visibleColumns;
  ScrollDirectionMode _scrollMode;
  bool _wrap;
  int _bufferSlots;
  final int? updateIntervalMs;
  int _lastStreamTickMs = 0;

  Map<String, dynamic> _data;
  final List<Media> _medias = [];
  late SlotPool _slotPool;

  int _focusedRow = 0;
  int _focusedCol = 0;
  int _viewportRowStart = 0;
  int _viewportColStart = 0;

  late List<int> _rowColOffsets;

  int _targetEpgTimeMinutes = 1200;
  bool _externalDataLoaded = false;
  bool _externalDataLoading = false;

  DataBindingController({
    required this.contextId,
    int? visibleRows,
    int? visibleColumns,
    ScrollDirectionMode? scrollMode,
    bool? wrap,
    int? bufferSlots,
    this.updateIntervalMs,
    Map<String, dynamic>? initialData,
    Iterable<Media>? medias,
    NclDocument? document,
    DataBindingLuaRuntime? luaRuntime,
  })  : luaRuntime = luaRuntime ??
            DataBindingLuaRuntime(
              document: document,
              media: medias?.firstOrNull,
            ),
        _visibleRows = visibleRows ?? 3,
        _visibleColumns = visibleColumns ?? 4,
        _scrollMode = scrollMode ?? ScrollDirectionMode.both,
        _wrap = wrap ?? false,
        _bufferSlots = bufferSlots ?? 2,
        _data = initialData ?? <String, dynamic>{} {
    if (medias != null) {
      for (final m in medias) {
        _addMediaInternal(m);
      }
      _deriveRegionAndDescriptorLayout(
        explicitRows: visibleRows,
        explicitColumns: visibleColumns,
        explicitScrollMode: scrollMode,
        explicitWrap: wrap,
        explicitBufferSlots: bufferSlots,
      );
    }
    if (_data.isNotEmpty) {
      this.luaRuntime.syncDataToLua(_data);
    }
    _slotPool = SlotPool(
      visibleRows: _visibleRows,
      visibleColumns: _visibleColumns,
      bufferSlots: _bufferSlots,
    );
    final totalR = math.max(1, totalRows);
    _rowColOffsets = List<int>.filled(totalR, 0, growable: true);
    _rebindVisibleViewport();
  }

  int get visibleRows => _visibleRows;
  int get visibleColumns => _visibleColumns;
  ScrollDirectionMode get scrollMode => _scrollMode;
  bool get wrap => _wrap;
  int get bufferSlots => _bufferSlots;
  SlotPool get slotPool => _slotPool;
  Map<String, dynamic> get data => _data;
  int get focusedRow => _focusedRow;
  int get focusedCol => _focusedCol;
  int get viewportRowStart => _viewportRowStart;
  int get viewportColStart => _viewportColStart;
  bool get hasLoadedExternalData => _externalDataLoaded || _data.isNotEmpty;
  bool get isLoadingExternalData => _externalDataLoading;

  void markExternalDataLoading(bool value) {
    _externalDataLoading = value;
  }

  void markExternalDataLoaded() {
    _externalDataLoaded = true;
    _externalDataLoading = false;
  }

  bool _addMediaInternal(Media media) {
    if (!_medias.any(
      (m) => identical(m, media) || (m.id != null && m.id == media.id),
    )) {
      _medias.add(media);
      return true;
    }
    return false;
  }

  void _deriveRegionAndDescriptorLayout({
    int? explicitRows,
    int? explicitColumns,
    ScrollDirectionMode? explicitScrollMode,
    bool? explicitWrap,
    int? explicitBufferSlots,
  }) {
    if (_medias.isEmpty) return;
    int? resolvedRows = explicitRows;
    int? resolvedCols = explicitColumns;
    bool hasVerticalScroll = false;
    bool hasHorizontalScroll = false;
    String? scrollStr;
    String? wrapStr;
    int? resolvedBuf = explicitBufferSlots;

    for (final m in _medias) {
      resolvedRows ??= int.tryParse(
        m.rawAttributes['regionRows'] ??
            m.rawAttributes['parentRegionRows'] ??
            m.rawAttributes['rows'] ??
            '',
      );
      resolvedCols ??= int.tryParse(
        m.rawAttributes['regionColumns'] ??
            m.rawAttributes['parentRegionColumns'] ??
            m.rawAttributes['columns'] ??
            '',
      );
      final scrollCandidates = [
        m.rawAttributes['regionScroll'],
        m.rawAttributes['parentRegionScroll'],
        m.rawAttributes['scroll'],
      ];
      for (final s in scrollCandidates) {
        if (s == null) continue;
        final sLower = s.trim().toLowerCase();
        if (sLower == 'both') {
          scrollStr = 'both';
        } else if (sLower == 'vertical') {
          hasVerticalScroll = true;
          scrollStr ??= 'vertical';
        } else if (sLower == 'horizontal') {
          hasHorizontalScroll = true;
          scrollStr ??= 'horizontal';
        }
      }
      wrapStr ??= m.rawAttributes['regionWrap'] ??
          m.rawAttributes['parentRegionWrap'] ??
          m.rawAttributes['wrap'];
      resolvedBuf ??= int.tryParse(
        m.rawAttributes['regionBufferSlots'] ??
            m.rawAttributes['parentRegionBufferSlots'] ??
            m.rawAttributes['bufferSlots'] ??
            '',
      );
    }

    if (resolvedRows != null && resolvedRows > 0) {
      _visibleRows = resolvedRows;
    }
    if (resolvedCols != null && resolvedCols > 0) {
      _visibleColumns = resolvedCols;
    }
    if (explicitScrollMode != null) {
      _scrollMode = explicitScrollMode;
    } else if (hasVerticalScroll && hasHorizontalScroll) {
      _scrollMode = ScrollDirectionMode.both;
    } else if (scrollStr != null) {
      _scrollMode = ScrollDirectionMode.fromString(scrollStr);
    }
    if (explicitWrap != null) {
      _wrap = explicitWrap;
    } else if (wrapStr != null) {
      _wrap = wrapStr.trim().toLowerCase() == 'true';
    }
    if (resolvedBuf != null && resolvedBuf >= 0) {
      _bufferSlots = resolvedBuf;
    }
  }

  void registerMedia(Media media) {
    if (_addMediaInternal(media)) {
      final prevRows = _visibleRows;
      final prevCols = _visibleColumns;
      final prevBuf = _bufferSlots;
      _deriveRegionAndDescriptorLayout();
      if (_visibleRows != prevRows ||
          _visibleColumns != prevCols ||
          _bufferSlots != prevBuf) {
        _slotPool = SlotPool(
          visibleRows: _visibleRows,
          visibleColumns: _visibleColumns,
          bufferSlots: _bufferSlots,
        );
      }
      _rebindVisibleViewport();
    }
  }

  List<BindingExpression> get mediaExpressions {
    final exprs = <BindingExpression>[];
    for (final m in _medias) {
      if (m.mimeType.startsWith('video/') || m.mimeType.startsWith('audio/')) {
        continue;
      }
      final raw = m.rawAttributes['src'] ?? m.src ?? '';
      if (BindingExpression.isDynamicExpression(raw)) {
        try {
          exprs.add(BindingExpression.parse(raw));
        } catch (_) {}
      }
    }
    return exprs;
  }

  List<BindingExpression> get columnOnlyExpressions =>
      mediaExpressions.where((e) => !e.usesRow && e.usesColumn).toList();

  List<BindingExpression> get rowExpressions =>
      mediaExpressions.where((e) => e.usesRow).toList();

  List<BindingExpression> get matrixExpressions =>
      mediaExpressions.where((e) => e.usesRow && e.usesColumn).toList();

  bool get hasMultiRailColumnMedias =>
      matrixExpressions.isEmpty &&
      rowExpressions.isEmpty &&
      columnOnlyExpressions.length > 1;

  bool get hasIndependentRowHorizontalScroll {
    if (hasTemporalSpanSchedule) return false;
    if (hasMultiRailColumnMedias) return true;
    final hasExplicitBothScrollRegion = _medias.any((m) {
      final s = m.rawAttributes['regionScroll']?.trim().toLowerCase();
      return s == 'both';
    });
    if (hasExplicitBothScrollRegion) return false;
    if (matrixExpressions.isNotEmpty && columnOnlyExpressions.isNotEmpty) {
      return false;
    }
    return matrixExpressions.isNotEmpty;
  }

  bool get hasTemporalSpanSchedule {
    final sched = _data['schedule'];
    if (sched is List && sched.isNotEmpty && sched.first is List) {
      final firstRow = sched.first as List;
      if (firstRow.isNotEmpty && firstRow.first is Map) {
        return (firstRow.first as Map).containsKey('span');
      }
    }
    return false;
  }

  int? railRowIndexForMedia(Media? media, [BindingExpression? expr]) {
    if (!hasMultiRailColumnMedias) return null;
    if (media != null) {
      final colMedias = _medias.where((m) {
        final raw = m.rawAttributes['src'] ?? m.src ?? '';
        if (!BindingExpression.isDynamicExpression(raw)) return false;
        try {
          final parsed = BindingExpression.parse(raw);
          return !parsed.usesRow && parsed.usesColumn;
        } catch (_) {
          return false;
        }
      }).toList();
      final idx = colMedias.indexWhere(
        (m) => identical(m, media) || (m.id != null && m.id == media.id),
      );
      if (idx != -1) return idx;
    }
    if (expr != null) {
      final colExprs = columnOnlyExpressions;
      final idx = colExprs.indexWhere(
        (e) => e.rootIdentifier == expr.rootIdentifier,
      );
      if (idx != -1) return idx;
    }
    return null;
  }

  int rowColOffsetForRow(int row) {
    if (row >= 0 && row < _rowColOffsets.length) {
      return _rowColOffsets[row];
    }
    return _viewportColStart;
  }

  Map<String, dynamic> executeLua(String luaCode) {
    final parsed = luaRuntime.execute(luaCode);
    if (parsed.isNotEmpty) {
      updateData(parsed);
    }
    return parsed;
  }

  void updateData(Map<String, dynamic> newData) {
    _data = newData;
    luaRuntime.syncDataToLua(_data);
    final totalR = math.max(1, totalRows);
    if (_rowColOffsets.length < totalR) {
      _rowColOffsets = List<int>.filled(totalR, 0, growable: true);
    }
    _focusedRow = _focusedRow.clamp(0, totalR - 1);
    _focusedCol = _focusedCol.clamp(0, math.max(0, totalColumnsForRow(_focusedRow) - 1));
    _rebindVisibleViewport();
    notifyListeners();
  }

  int get totalRows {
    for (final expr in rowExpressions) {
      final col = _data[expr.rootIdentifier];
      if (col is List && col.isNotEmpty) {
        return col.length;
      }
    }
    if (hasMultiRailColumnMedias) {
      return columnOnlyExpressions.length;
    }
    for (final entry in _data.entries) {
      if (entry.key.startsWith('__')) continue;
      final val = entry.value;
      if (val is List && val.isNotEmpty) {
        return val.length;
      }
    }
    return visibleRows;
  }

  int totalColumnsForRow(int row) {
    for (final expr in matrixExpressions) {
      final col = _data[expr.rootIdentifier];
      if (col is List && row >= 0 && row < col.length) {
        final rList = col[row];
        if (rList is List && rList.isNotEmpty) {
          return rList.length;
        }
      }
    }
    if (hasMultiRailColumnMedias) {
      final colExprs = columnOnlyExpressions;
      if (row >= 0 && row < colExprs.length) {
        final rowData = _data[colExprs[row].rootIdentifier];
        if (rowData is List && rowData.isNotEmpty) {
          return rowData.length;
        }
      }
    }
    for (final expr in columnOnlyExpressions) {
      final col = _data[expr.rootIdentifier];
      if (col is List && col.isNotEmpty) {
        return col.length;
      }
    }
    for (final entry in _data.entries) {
      if (entry.key.startsWith('__')) continue;
      final val = entry.value;
      if (val is List && val.isNotEmpty) {
        if (row >= 0 && row < val.length && val[row] is List) {
          final rList = val[row] as List;
          if (rList.isNotEmpty) return rList.length;
        }
      }
    }
    for (final entry in _data.entries) {
      if (entry.key.startsWith('__')) continue;
      final val = entry.value;
      if (val is List && val.isNotEmpty && val.first is! List) {
        return val.length;
      }
    }
    return visibleColumns;
  }

  bool handleKey(String rawKey) {
    final key = rawKey.trim().toUpperCase();
    bool changed = false;

    switch (key) {
      case 'CURSOR_RIGHT':
      case 'ARROWRIGHT':
      case 'RIGHT':
        changed = _stepRight();
        break;
      case 'CURSOR_LEFT':
      case 'ARROWLEFT':
      case 'LEFT':
        changed = _stepLeft();
        break;
      case 'CURSOR_DOWN':
      case 'ARROWDOWN':
      case 'DOWN':
        changed = _stepDown();
        break;
      case 'CURSOR_UP':
      case 'ARROWUP':
      case 'UP':
        changed = _stepUp();
        break;
      case 'ENTER':
      case 'OK':
      case 'SELECT':
        changed = true;
        break;
      default:
        return false;
    }

    if (changed) {
      _rebindVisibleViewport();
      notifyListeners();
    }
    return true;
  }

  bool _stepRight() {
    if (scrollMode == ScrollDirectionMode.vertical) return false;
    final maxCols = totalColumnsForRow(_focusedRow);
    if (maxCols <= 0) return false;

    if (_focusedCol < maxCols - 1) {
      _focusedCol++;
      if (_focusedCol >= _viewportColStart + visibleColumns) {
        _viewportColStart = _focusedCol - visibleColumns + 1;
      }
    } else if (wrap) {
      _focusedCol = 0;
      _viewportColStart = 0;
    } else {
      return false;
    }

    _syncRowSpecificState();
    _updateTargetTimeFromFocus();
    return true;
  }

  bool _stepLeft() {
    if (scrollMode == ScrollDirectionMode.vertical) return false;
    final maxCols = totalColumnsForRow(_focusedRow);
    if (maxCols <= 0) return false;

    if (_focusedCol > 0) {
      _focusedCol--;
      if (_focusedCol < _viewportColStart) {
        _viewportColStart = _focusedCol;
      }
    } else if (wrap) {
      _focusedCol = maxCols - 1;
      _viewportColStart = math.max(0, maxCols - visibleColumns);
    } else {
      return false;
    }

    _syncRowSpecificState();
    _updateTargetTimeFromFocus();
    return true;
  }

  bool _stepDown() {
    if (scrollMode == ScrollDirectionMode.horizontal) return false;
    final maxRows = totalRows;
    if (maxRows <= 0) return false;

    int nextRow = _focusedRow;
    if (_focusedRow < maxRows - 1) {
      nextRow = _focusedRow + 1;
      if (nextRow >= _viewportRowStart + visibleRows) {
        _viewportRowStart = nextRow - visibleRows + 1;
      }
    } else if (wrap) {
      nextRow = 0;
      _viewportRowStart = 0;
    } else {
      return false;
    }

    _focusedRow = nextRow;
    _projectColumnForNewRow(nextRow);
    return true;
  }

  bool _stepUp() {
    if (scrollMode == ScrollDirectionMode.horizontal) return false;
    final maxRows = totalRows;
    if (maxRows <= 0) return false;

    int nextRow = _focusedRow;
    if (_focusedRow > 0) {
      nextRow = _focusedRow - 1;
      if (nextRow < _viewportRowStart) {
        _viewportRowStart = nextRow;
      }
    } else if (wrap) {
      nextRow = maxRows - 1;
      _viewportRowStart = math.max(0, maxRows - visibleRows);
    } else {
      return false;
    }

    _focusedRow = nextRow;
    _projectColumnForNewRow(nextRow);
    return true;
  }

  void _syncRowSpecificState() {
    if (_focusedRow >= 0 && _focusedRow < _rowColOffsets.length) {
      _rowColOffsets[_focusedRow] = _viewportColStart;
    }
  }

  void _projectColumnForNewRow(int targetRow) {
    final maxCols = totalColumnsForRow(targetRow);
    if (hasTemporalSpanSchedule) {
      _focusedCol = _findColumnForTime(targetRow, _targetEpgTimeMinutes);
      if (_focusedCol < _viewportColStart) {
        _viewportColStart = _focusedCol;
      } else if (_focusedCol >= _viewportColStart + visibleColumns) {
        _viewportColStart = _focusedCol - visibleColumns + 1;
      }
      return;
    }

    if (hasIndependentRowHorizontalScroll &&
        targetRow >= 0 &&
        targetRow < _rowColOffsets.length) {
      final int visualSlot =
          (_focusedCol - _viewportColStart).clamp(0, math.max(0, visibleColumns - 1));
      _viewportColStart = _rowColOffsets[targetRow].clamp(
        0,
        math.max(0, maxCols - visibleColumns),
      );
      _focusedCol =
          (_viewportColStart + visualSlot).clamp(0, math.max(0, maxCols - 1));
      return;
    }

    _focusedCol = _focusedCol.clamp(0, math.max(0, maxCols - 1));
    if (_focusedCol < _viewportColStart) {
      _viewportColStart = _focusedCol;
    } else if (_focusedCol >= _viewportColStart + visibleColumns) {
      _viewportColStart = math.max(0, _focusedCol - visibleColumns + 1);
    }
  }

  void _updateTargetTimeFromFocus() {
    if (!hasTemporalSpanSchedule) return;
    final sched = _data['schedule'];
    if (sched is! List || _focusedRow < 0 || _focusedRow >= sched.length) {
      return;
    }
    final rowProg = sched[_focusedRow];
    if (rowProg is! List) return;

    int elapsedMin = 1200;
    for (int c = 0; c < rowProg.length; c++) {
      final cell = rowProg[c];
      final span = (cell is Map ? (cell['span'] as int? ?? 1) : 1);
      final dur = span * 30;
      if (c == _focusedCol) {
        _targetEpgTimeMinutes = elapsedMin;
        return;
      }
      elapsedMin += dur;
    }
  }

  int _findColumnForTime(int row, int targetMinutes) {
    final sched = _data['schedule'];
    if (sched is! List || row < 0 || row >= sched.length) return 0;
    final rowProg = sched[row];
    if (rowProg is! List || rowProg.isEmpty) return 0;

    int elapsedMin = 1200;
    for (int c = 0; c < rowProg.length; c++) {
      final cell = rowProg[c];
      final span = (cell is Map ? (cell['span'] as int? ?? 1) : 1);
      final startMin = elapsedMin;
      final endMin = startMin + span * 30;
      if (targetMinutes >= startMin && targetMinutes < endMin) {
        return c;
      }
      elapsedMin = endMin;
    }
    return rowProg.length - 1;
  }

  void tickStream(int virtualClockMs) {
    final interval = updateIntervalMs;
    if (interval == null || interval <= 0) return;
    if (virtualClockMs - _lastStreamTickMs < interval) {
      return;
    }
    _lastStreamTickMs = virtualClockMs;
    final updated = luaRuntime.callLuaFunction('onTick', [virtualClockMs]);
    if (updated.isNotEmpty) {
      updateData(updated);
    }
  }

  @override
  void dispose() {
    luaRuntime.dispose();
    super.dispose();
  }

  void _rebindVisibleViewport() {
    final maxR = math.min(totalRows, _viewportRowStart + visibleRows);
    for (int r = _viewportRowStart; r < maxR; r++) {
      final rowColStart =
          (hasIndependentRowHorizontalScroll && r < _rowColOffsets.length)
              ? _rowColOffsets[r]
              : _viewportColStart;
      final maxC = math.min(
        totalColumnsForRow(r),
        rowColStart + visibleColumns,
      );
      for (int c = rowColStart; c < maxC; c++) {
        final slot = slotPool.acquireSlot(r, c);
        slot.bind(
          logicalRow: r,
          logicalCol: c,
        );
      }
    }
  }
}
