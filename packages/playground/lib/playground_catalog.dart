import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:gingacc/gingacc.dart';
import 'package:material_ui/material_ui.dart';

const String defaultCatalogExamplesBaseUrl =
    'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples';

String catalogExamplesBaseUrl = defaultCatalogExamplesBaseUrl;

String resolveCatalogExampleUrl(String pathOrUrl) {
  final trimmed = pathOrUrl.trim();
  if (trimmed.isEmpty ||
      isHttpUri(trimmed) ||
      isXmlString(trimmed) ||
      trimmed.startsWith('file:') ||
      trimmed.startsWith('data:') ||
      trimmed.startsWith('blob:')) {
    return trimmed;
  }
  var clean = trimmed.replaceAll('\\', '/');
  while (clean.startsWith('./')) {
    clean = clean.substring(2);
  }
  if (clean.startsWith('/')) {
    clean = clean.substring(1);
  }
  if (clean.startsWith('examples/')) {
    clean = clean.substring('examples/'.length);
  }
  final base = catalogExamplesBaseUrl.endsWith('/')
      ? catalogExamplesBaseUrl.substring(0, catalogExamplesBaseUrl.length - 1)
      : catalogExamplesBaseUrl;
  return '$base/$clean';
}

class CatalogExample {
  static const List<String> canonicalTypes = ['NCL', 'HTML'];

  final String key;
  final String mainFile;
  final String type;
  final String category;
  final String description;
  final List<String> otherEditableFiles;

  const CatalogExample({
    required this.key,
    required this.mainFile,
    String? type,
    this.category = 'general',
    this.description = '',
    this.otherEditableFiles = const [],
  }) : type = type ?? 'NCL';

  static String inferType(String mainFile, [String? rawType]) {
    final trimmed = rawType?.trim().toUpperCase();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    final clean = mainFile.toLowerCase().split('?').first.split('#').first;
    if (clean.endsWith('.html') ||
        clean.endsWith('.htm') ||
        clean.endsWith('.xhtml')) {
      return 'HTML';
    }
    return 'NCL';
  }

  factory CatalogExample.fromJson(String key, Map<String, dynamic> json) {
    final mainFile = json['mainFile'] as String? ?? key;
    return CatalogExample(
      key: key,
      mainFile: mainFile,
      type: inferType(mainFile, json['type'] as String?),
      category: json['category'] as String? ?? 'general',
      description: json['description'] as String? ?? '',
      otherEditableFiles: ((json['otherEditbleFiles'] ??
                  json['otherEditableFiles']) as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

List<CatalogExample> parseCatalog(dynamic jsonInput) {
  Map<String, dynamic> data;
  if (jsonInput is String) {
    try {
      data = jsonDecode(jsonInput) as Map<String, dynamic>;
    } catch (_) {
      return [];
    }
  } else if (jsonInput is Map<String, dynamic>) {
    data = jsonInput;
  } else if (jsonInput is Map) {
    data = Map<String, dynamic>.from(jsonInput);
  } else {
    return [];
  }

  final examplesMap = data['examples'];
  if (examplesMap is! Map) return [];

  final list = <CatalogExample>[];
  for (final entry in examplesMap.entries) {
    if (entry.value is Map) {
      list.add(CatalogExample.fromJson(
        entry.key.toString(),
        Map<String, dynamic>.from(entry.value as Map),
      ));
    }
  }
  return list;
}

Future<List<CatalogExample>> loadCatalogExamples({
  GingaCC? gingacc,
  Map<String, dynamic>? customCatalogData,
  String? catalogJsonContent,
}) async {
  if (customCatalogData != null) {
    return parseCatalog(customCatalogData);
  }
  if (catalogJsonContent != null) {
    return parseCatalog(catalogJsonContent);
  }

  final cc = gingacc ?? GingaCC();
  final catalogUrl = resolveCatalogExampleUrl('catalog.json');
  try {
    final content = await cc.loadContent(catalogUrl);
    if (content != null && content.isNotEmpty) {
      final parsed = parseCatalog(content);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
  } catch (_) {}

  if (catalogExamplesBaseUrl != defaultCatalogExamplesBaseUrl &&
      catalogExamplesBaseUrl.startsWith('http')) {
    try {
      final fallbackContent =
          await cc.loadContent('$defaultCatalogExamplesBaseUrl/catalog.json');
      if (fallbackContent != null && fallbackContent.isNotEmpty) {
        catalogExamplesBaseUrl = defaultCatalogExamplesBaseUrl;
        return parseCatalog(fallbackContent);
      }
    } catch (_) {}
  }

  return [];
}

Future<String?> loadExampleContent(
  String mainFile, {
  GingaCC? gingacc,
}) async {
  final trimmed = mainFile.trim();
  if (trimmed.isEmpty) return null;

  final cc = gingacc ?? GingaCC();
  final githubUrl = resolveCatalogExampleUrl(trimmed);
  try {
    final content = await cc.loadContent(githubUrl);
    if (content != null && content.isNotEmpty) {
      return content;
    }
  } catch (_) {}

  return null;
}

typedef CatalogGridView = AppCatalogView;

class AppCatalogView extends StatefulWidget {
  final List<CatalogExample> examples;
  final String? selectedExample;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  const AppCatalogView({
    super.key,
    required this.examples,
    this.selectedExample,
    required this.onSelected,
    required this.onClose,
  });

  @override
  State<AppCatalogView> createState() => _AppCatalogViewState();
}

class _AppCatalogViewState extends State<AppCatalogView> {
  final FocusNode _galleryFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<String> _expandedTypes = {'NCL', 'HTML'};
  String? _activeTypeFilter;
  String? _activeCategoryFilter;
  String _searchQuery = '';
  int _lastColumnCount = 3;
  String? _focusedKey;
  String? _hoveredKey;

  @override
  void initState() {
    super.initState();
    _syncExpandedTypes();
    _initFocus();
  }

  @override
  void didUpdateWidget(covariant AppCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.examples != oldWidget.examples) {
      _syncExpandedTypes();
      if (_focusedKey == null) {
        _initFocus();
      }
    }
  }

  void _syncExpandedTypes() {
    for (final item in widget.examples) {
      final t = item.type.trim().isNotEmpty
          ? item.type.trim().toUpperCase()
          : 'NCL';
      _expandedTypes.add(t);
    }
  }

  @override
  void dispose() {
    _galleryFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initFocus() {
    if (widget.examples.isEmpty) return;
    if (widget.selectedExample != null) {
      for (final item in widget.examples) {
        if (_isSelected(item)) {
          _focusedKey = item.key;
          return;
        }
      }
    }
    final tree = _groupByTypeAndCategory();
    final flat = _buildFlatItems(tree);
    if (flat.isNotEmpty) {
      _focusedKey = flat.first.key;
    }
  }

  GlobalKey _keyForItem(String itemKey) {
    return _itemKeys.putIfAbsent(itemKey, () => GlobalKey());
  }

  bool _matchesSearch(CatalogExample item, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (item.key.toLowerCase().contains(q)) return true;
    if (item.type.toLowerCase().contains(q)) return true;
    if (item.description.toLowerCase().contains(q)) return true;
    if (item.category.toLowerCase().contains(q)) return true;
    if (item.mainFile.toLowerCase().contains(q)) return true;
    for (final file in item.otherEditableFiles) {
      if (file.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  Map<String, Map<String, List<CatalogExample>>> _groupByTypeAndCategory({
    String query = '',
  }) {
    final Map<String, Map<String, List<CatalogExample>>> raw = {};
    for (final item in widget.examples) {
      if (!_matchesSearch(item, query)) continue;
      final t = item.type.trim().isNotEmpty
          ? item.type.trim().toUpperCase()
          : 'NCL';
      final cat =
          item.category.trim().isNotEmpty ? item.category.trim() : 'general';
      raw.putIfAbsent(t, () => {}).putIfAbsent(cat, () => []).add(item);
    }

    final Map<String, Map<String, List<CatalogExample>>> ordered = {};
    for (final canonical in CatalogExample.canonicalTypes) {
      if (raw.containsKey(canonical)) {
        ordered[canonical] = raw[canonical]!;
      }
    }
    for (final entry in raw.entries) {
      if (!ordered.containsKey(entry.key)) {
        ordered[entry.key] = entry.value;
      }
    }
    return ordered;
  }

  Map<String, Map<String, List<CatalogExample>>> _visibleTree(
    Map<String, Map<String, List<CatalogExample>>> filteredTree,
  ) {
    if (_activeTypeFilter == null && _activeCategoryFilter == null) {
      return filteredTree;
    }
    final Map<String, Map<String, List<CatalogExample>>> result = {};
    for (final typeEntry in filteredTree.entries) {
      if (_activeTypeFilter != null && typeEntry.key != _activeTypeFilter) {
        continue;
      }
      if (_activeCategoryFilter == null) {
        if (typeEntry.value.isNotEmpty) {
          result[typeEntry.key] = typeEntry.value;
        }
      } else {
        final catItems = typeEntry.value[_activeCategoryFilter];
        if (catItems != null && catItems.isNotEmpty) {
          result[typeEntry.key] = {_activeCategoryFilter!: catItems};
        }
      }
    }
    return result;
  }

  List<List<CatalogExample>> _buildVisualRows(
    Map<String, Map<String, List<CatalogExample>>> tree,
    int columns,
  ) {
    final cols = math.max(1, columns);
    final rows = <List<CatalogExample>>[];
    for (final catMap in tree.values) {
      for (final items in catMap.values) {
        for (var i = 0; i < items.length; i += cols) {
          rows.add(items.sublist(i, math.min(i + cols, items.length)));
        }
      }
    }
    return rows;
  }

  List<CatalogExample> _buildFlatItems(
    Map<String, Map<String, List<CatalogExample>>> tree,
  ) {
    return [
      for (final catMap in tree.values)
        for (final items in catMap.values) ...items,
    ];
  }

  int _countTypeItems(Map<String, List<CatalogExample>>? catMap) {
    if (catMap == null) return 0;
    var total = 0;
    for (final items in catMap.values) {
      total += items.length;
    }
    return total;
  }

  void _ensureFocusedVisible() {
    final key = _focusedKey;
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _itemKeys[key]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _updateSearchQuery(String value) {
    final trimmed = value.trim();
    setState(() {
      _searchQuery = trimmed;
      final visible = _visibleTree(_groupByTypeAndCategory(query: _searchQuery));
      final flat = _buildFlatItems(visible);
      if (flat.isNotEmpty && !flat.any((e) => e.key == _focusedKey)) {
        _focusedKey = flat.first.key;
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }

    final searchFocused = _searchFocusNode.hasFocus;
    if (searchFocused &&
        (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      return KeyEventResult.ignored;
    }

    final filteredTree = _groupByTypeAndCategory(query: _searchQuery);
    final visible = _visibleTree(filteredTree);
    final items = _buildFlatItems(visible);
    if (items.isEmpty) {
      return KeyEventResult.ignored;
    }

    var idx = items.indexWhere((e) => e.key == _focusedKey);
    if (idx == -1) idx = 0;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        (!searchFocused && key == LogicalKeyboardKey.space)) {
      widget.onSelected(items[idx].mainFile);
      return KeyEventResult.handled;
    }

    String? nextKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      nextKey = items[math.min(idx + 1, items.length - 1)].key;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      nextKey = items[math.max(idx - 1, 0)].key;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final rows = _buildVisualRows(visible, _lastColumnCount);
      var rowIdx = 0;
      var colIdx = 0;
      for (var r = 0; r < rows.length; r++) {
        final c = rows[r].indexWhere((e) => e.key == items[idx].key);
        if (c != -1) {
          rowIdx = r;
          colIdx = c;
          break;
        }
      }
      final targetRow = key == LogicalKeyboardKey.arrowDown
          ? math.min(rowIdx + 1, rows.length - 1)
          : math.max(rowIdx - 1, 0);
      final targetCol = math.min(colIdx, rows[targetRow].length - 1);
      nextKey = rows[targetRow][targetCol].key;
    } else {
      return KeyEventResult.ignored;
    }

    if (nextKey != _focusedKey) {
      setState(() {
        _focusedKey = nextKey;
      });
      _ensureFocusedVisible();
    }
    return KeyEventResult.handled;
  }

  static String formatCategoryTitle(String category) {
    return category.replaceAll('_', ' ').toUpperCase();
  }

  static String _formatNavCategoryLabel(String category) {
    final cleaned = category.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'General';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static (IconData, Color, String) _metaForType(String type) {
    if (type.toUpperCase() == 'HTML') {
      return (
        Icons.html_rounded,
        const Color(0xFFFB923C),
        'Web & Ginga-HTML5 applications',
      );
    }
    return (
      Icons.code_rounded,
      const Color(0xFF38BDF8),
      'Declarative multimedia & NCLua applications',
    );
  }

  static IconData _iconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('360') || lower.contains('vr')) {
      return Icons.panorama_photosphere_outlined;
    }
    if (lower.contains('lua')) {
      return Icons.terminal_rounded;
    }
    if (lower.contains('multi') || lower.contains('device')) {
      return Icons.devices_rounded;
    }
    if (lower.contains('ginga.org')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('html') || lower.contains('web')) {
      return Icons.language_rounded;
    }
    if (lower.contains('user')) {
      return Icons.people_outline_rounded;
    }
    return Icons.widgets_outlined;
  }

  (IconData, String, Color) _resolveBadge(CatalogExample item) {
    final lower = item.mainFile.toLowerCase();
    final hasLua = lower.endsWith('.lua') ||
        item.otherEditableFiles.any((f) => f.toLowerCase().endsWith('.lua'));
    if (lower.endsWith('.ncl360') ||
        item.category.toLowerCase().contains('360')) {
      return (
        Icons.panorama_photosphere,
        '360',
        const Color(0xFFC084FC),
      );
    }
    if (item.type.toUpperCase() == 'HTML' ||
        lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.xhtml')) {
      return (
        Icons.html,
        'HTML',
        const Color(0xFFFB923C),
      );
    }
    if (hasLua) {
      return (
        Icons.terminal,
        'NCL + LUA',
        const Color(0xFF34D399),
      );
    }
    return (
      Icons.code,
      'NCL',
      const Color(0xFF38BDF8),
    );
  }

  bool _isSelected(CatalogExample item) {
    if (widget.selectedExample == null) return false;
    return item.mainFile == widget.selectedExample ||
        'examples/${item.mainFile}' == widget.selectedExample ||
        resolveCatalogExampleUrl(item.mainFile) == widget.selectedExample ||
        item.key == widget.selectedExample;
  }

  Widget _buildHeaderBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF202022),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2D2D30), width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          const Icon(
            Icons.grid_view_rounded,
            color: Color(0xFF38BDF8),
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            'Application Catalog',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFE5E5E5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B2E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF3E3E42),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('catalog_search_input'),
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _updateSearchQuery,
                          style: const TextStyle(
                            color: Color(0xFFE5E5E5),
                            fontSize: 12.5,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Search examples and categories...',
                            hintStyle: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          key: const Key('catalog_search_clear'),
                          tooltip: 'Clear search',
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Color(0xFF9E9E9E),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _updateSearchQuery('');
                            _galleryFocusNode.requestFocus();
                          },
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.search_rounded,
                            size: 15,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            key: const Key('catalog_dialog_close'),
            tooltip: 'Close Catalog',
            icon: const Icon(
              Icons.close,
              color: Color(0xFF9E9E9E),
              size: 18,
            ),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTypeHeader({
    required String type,
    required int count,
    required bool isSelected,
    required bool isExpanded,
    required VoidCallback onTap,
    required VoidCallback onToggleExpand,
  }) {
    final (icon, accentColor, _) = _metaForType(type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('catalog_type_chip_$type'),
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2D2D32) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 17,
                  color: isSelected ? accentColor : const Color(0xFFC8C8D0),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFE5E5EA),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFB0B0B5)
                        : const Color(0xFF7A7A80),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                InkWell(
                  key: Key('catalog_type_expand_$type'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: onToggleExpand,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 16,
                      color: const Color(0xFF9E9EA6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavCategoryItem({
    required Key key,
    required IconData icon,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    bool indented = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            height: 34,
            padding: EdgeInsets.only(
              left: indented ? 22 : 8,
              right: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2D2D32) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 15,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFFA8A8B0),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFCCCCD2),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFB0B0B5)
                        : const Color(0xFF7A7A80),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationPane(
    Map<String, Map<String, List<CatalogExample>>> allTree,
    Map<String, Map<String, List<CatalogExample>>> filteredTree,
  ) {
    final totalFiltered = _buildFlatItems(filteredTree).length;
    final usedCategoryKeys = <String>{};

    return SizedBox(
      key: const Key('catalog_category_pane'),
      width: 220.0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F22),
          border: Border(
            right: BorderSide(color: Color(0xFF2D2D30), width: 1),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildNavCategoryItem(
              key: const Key('catalog_category_chip_all'),
              icon: Icons.apps_rounded,
              label: 'All',
              count: totalFiltered,
              isSelected:
                  _activeTypeFilter == null && _activeCategoryFilter == null,
              onTap: () {
                setState(() {
                  _activeTypeFilter = null;
                  _activeCategoryFilter = null;
                  final flat = _buildFlatItems(filteredTree);
                  if (flat.isNotEmpty) {
                    _focusedKey = flat.first.key;
                  }
                });
                _galleryFocusNode.requestFocus();
              },
            ),
            if (allTree.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Divider(
                  color: Color(0xFF2D2D30),
                  height: 1,
                  thickness: 1,
                ),
              ),
            for (final typeEntry in allTree.entries) ...[
              _buildNavTypeHeader(
                type: typeEntry.key,
                count: _countTypeItems(filteredTree[typeEntry.key]),
                isSelected: _activeTypeFilter == typeEntry.key &&
                    _activeCategoryFilter == null,
                isExpanded: _expandedTypes.contains(typeEntry.key),
                onTap: () {
                  setState(() {
                    _activeTypeFilter = typeEntry.key;
                    _activeCategoryFilter = null;
                    final typeMap = filteredTree[typeEntry.key];
                    if (typeMap != null) {
                      final flat = _buildFlatItems({typeEntry.key: typeMap});
                      if (flat.isNotEmpty) {
                        _focusedKey = flat.first.key;
                      }
                    }
                  });
                  _galleryFocusNode.requestFocus();
                },
                onToggleExpand: () {
                  setState(() {
                    if (_expandedTypes.contains(typeEntry.key)) {
                      _expandedTypes.remove(typeEntry.key);
                    } else {
                      _expandedTypes.add(typeEntry.key);
                    }
                  });
                },
              ),
              if (_expandedTypes.contains(typeEntry.key))
                for (final catEntry in typeEntry.value.entries)
                  Builder(
                    builder: (context) {
                      final rawCat = catEntry.key;
                      final chipKeyStr = usedCategoryKeys.add(rawCat)
                          ? 'catalog_category_chip_$rawCat'
                          : 'catalog_category_chip_${typeEntry.key.toLowerCase()}_$rawCat';
                      return _buildNavCategoryItem(
                        key: Key(chipKeyStr),
                        icon: _iconForCategory(rawCat),
                        label: _formatNavCategoryLabel(rawCat),
                        count:
                            filteredTree[typeEntry.key]?[rawCat]?.length ?? 0,
                        indented: true,
                        isSelected: _activeTypeFilter == typeEntry.key &&
                            _activeCategoryFilter == rawCat,
                        onTap: () {
                          setState(() {
                            _activeTypeFilter = typeEntry.key;
                            _activeCategoryFilter = rawCat;
                            final catItems =
                                filteredTree[typeEntry.key]?[rawCat] ??
                                    const [];
                            if (catItems.isNotEmpty) {
                              _focusedKey = catItems.first.key;
                            }
                          });
                          _galleryFocusNode.requestFocus();
                        },
                      );
                    },
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryCard(CatalogExample item, double cardWidth) {
    final isSelected = _isSelected(item);
    final isFocused = _focusedKey == item.key;
    final isHovered = _hoveredKey == item.key;
    final (icon, badgeText, iconAccent) = _resolveBadge(item);

    Color bgColor = const Color(0xFF28282B);
    if (isSelected) {
      bgColor = const Color(0xFF2B3540);
    } else if (isFocused || isHovered) {
      bgColor = const Color(0xFF313136);
    }

    Color borderColor = const Color(0xFF36363A);
    if (isSelected) {
      borderColor = const Color(0xFF38BDF8);
    } else if (isFocused || isHovered) {
      borderColor = const Color(0xFF525258);
    }

    return SizedBox(
      key: _keyForItem(item.key),
      width: cardWidth,
      child: MouseRegion(
        onEnter: (_) {
          if (_hoveredKey != item.key) {
            setState(() {
              _hoveredKey = item.key;
              _focusedKey = item.key;
            });
          }
        },
        onExit: (_) {
          if (_hoveredKey == item.key) {
            setState(() {
              _hoveredKey = null;
            });
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('catalog_option_${item.key}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.onSelected(item.mainFile),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              height: 82,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E21),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF343438),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: iconAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFEAEAEF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E21),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF3E3E44),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
                                  color: Color(0xFFB4B4BC),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (item.otherEditableFiles.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '+${item.otherEditableFiles.length}',
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description.isNotEmpty
                              ? item.description
                              : item.mainFile,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9E9EA6),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String type,
    String category,
    List<CatalogExample> items,
    double availableWidth,
    int columns,
    Set<String> usedHeaderKeys,
  ) {
    final categoryTitle = formatCategoryTitle(category);
    final headerKeyStr = usedHeaderKeys.add(category)
        ? 'catalog_category_header_$category'
        : 'catalog_category_header_${type.toLowerCase()}_$category';
    const double spacing = 12.0;
    final double cardWidth = math.max(
      180.0,
      (availableWidth - spacing * (columns - 1)) / columns,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  categoryTitle,
                  key: Key(headerKeyStr),
                  style: const TextStyle(
                    color: Color(0xFFB8B8C2),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D32),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Color(0xFFA0A0A8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items) _buildGalleryCard(item, cardWidth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTopSection(
    String type,
    Map<String, List<CatalogExample>> categories,
    double availableWidth,
    int columns,
    Set<String> usedHeaderKeys,
  ) {
    final (icon, accentColor, subtitle) = _metaForType(type);
    final totalCount = _countTypeItems(categories);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: Key('catalog_type_header_$type'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF232327),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF323238),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            type,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E2E34),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalCount',
                              style: const TextStyle(
                                color: Color(0xFFC8C8D0),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF94949E),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final catEntry in categories.entries)
            _buildCategorySection(
              type,
              catEntry.key,
              catEntry.value,
              availableWidth,
              columns,
              usedHeaderKeys,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTree = _groupByTypeAndCategory();
    final filteredTree = _groupByTypeAndCategory(query: _searchQuery);
    final visible = _visibleTree(filteredTree);

    return Focus(
      focusNode: _galleryFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        color: const Color(0xFF1C1C1E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNavigationPane(allTree, filteredTree),
                  Expanded(
                    key: const Key('catalog_content_area'),
                    child: widget.examples.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No applications available in catalog',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : visible.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.search_off_rounded,
                                        size: 36,
                                        color: Color(0xFF6E6E73),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No examples match "$_searchQuery"'
                                            : 'No examples in this category',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF9E9EA6),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  const double horizontalPad = 24.0;
                                  final innerWidth = math.max(
                                    200.0,
                                    constraints.maxWidth - horizontalPad * 2,
                                  );
                                  final cols = innerWidth >= 920
                                      ? 3
                                      : (innerWidth >= 540 ? 2 : 1);
                                  _lastColumnCount = cols;
                                  final usedHeaderKeys = <String>{};

                                  return SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      horizontalPad,
                                      20,
                                      horizontalPad,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final typeEntry in visible.entries)
                                          _buildTypeTopSection(
                                            typeEntry.key,
                                            typeEntry.value,
                                            innerWidth,
                                            cols,
                                            usedHeaderKeys,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
