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
  final String key;
  final String mainFile;
  final String category;
  final String description;
  final List<String> otherEditableFiles;

  const CatalogExample({
    required this.key,
    required this.mainFile,
    this.category = 'general',
    this.description = '',
    this.otherEditableFiles = const [],
  });

  factory CatalogExample.fromJson(String key, Map<String, dynamic> json) {
    return CatalogExample(
      key: key,
      mainFile: json['mainFile'] as String? ?? key,
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
  final FocusNode _listFocusNode = FocusNode();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _activeCategoryFilter;
  String? _focusedKey;
  String? _hoveredKey;

  @override
  void initState() {
    super.initState();
    _initFocus();
  }

  @override
  void didUpdateWidget(covariant AppCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.examples != oldWidget.examples && _focusedKey == null) {
      _initFocus();
    }
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
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
    _focusedKey = widget.examples.first.key;
  }

  GlobalKey _keyForItem(String itemKey) {
    return _itemKeys.putIfAbsent(itemKey, () => GlobalKey());
  }

  Map<String, List<CatalogExample>> _groupByCategory() {
    final Map<String, List<CatalogExample>> grouped = {};
    for (final item in widget.examples) {
      final cat =
          item.category.trim().isNotEmpty ? item.category.trim() : 'general';
      grouped.putIfAbsent(cat, () => []).add(item);
    }
    return grouped;
  }

  Map<String, List<CatalogExample>> _visibleGroups(
    Map<String, List<CatalogExample>> allGroups,
  ) {
    if (_activeCategoryFilter == null ||
        !allGroups.containsKey(_activeCategoryFilter)) {
      return allGroups;
    }
    return {_activeCategoryFilter!: allGroups[_activeCategoryFilter!]!};
  }

  List<CatalogExample> _buildFlatItems(
    Map<String, List<CatalogExample>> groups,
  ) {
    return [
      for (final items in groups.values) ...items,
    ];
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }

    final allGroups = _groupByCategory();
    final visible = _visibleGroups(allGroups);
    final items = _buildFlatItems(visible);
    if (items.isEmpty) {
      return KeyEventResult.ignored;
    }

    var idx = items.indexWhere((e) => e.key == _focusedKey);
    if (idx == -1) idx = 0;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      widget.onSelected(items[idx].mainFile);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      idx = math.min(idx + 1, items.length - 1);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      idx = math.max(idx - 1, 0);
    } else {
      return KeyEventResult.ignored;
    }

    final nextKey = items[idx].key;
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

  (IconData, String) _resolveBadge(CatalogExample item) {
    final lower = item.mainFile.toLowerCase();
    final hasLua = lower.endsWith('.lua') ||
        item.otherEditableFiles.any((f) => f.toLowerCase().endsWith('.lua'));
    if (lower.endsWith('.ncl360') ||
        item.category.toLowerCase().contains('360')) {
      return (Icons.panorama_photosphere, '360');
    }
    if (lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.xhtml')) {
      return (Icons.html, 'HTML');
    }
    if (hasLua) {
      return (Icons.terminal, 'NCL + LUA');
    }
    return (Icons.code, 'NCL');
  }

  bool _isSelected(CatalogExample item) {
    if (widget.selectedExample == null) return false;
    return item.mainFile == widget.selectedExample ||
        'examples/${item.mainFile}' == widget.selectedExample ||
        resolveCatalogExampleUrl(item.mainFile) == widget.selectedExample ||
        item.key == widget.selectedExample;
  }

  Widget _buildCategoryFilterBar(Map<String, List<CatalogExample>> allGroups) {
    if (allGroups.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildCategoryChip(
            key: const Key('catalog_category_chip_all'),
            label: 'ALL (${widget.examples.length})',
            isSelected: _activeCategoryFilter == null,
            onTap: () {
              setState(() {
                _activeCategoryFilter = null;
                if (widget.examples.isNotEmpty) {
                  _focusedKey = widget.examples.first.key;
                }
              });
              _listFocusNode.requestFocus();
            },
          ),
          for (final entry in allGroups.entries)
            _buildCategoryChip(
              key: Key('catalog_category_chip_${entry.key}'),
              label:
                  '${formatCategoryTitle(entry.key)} (${entry.value.length})',
              isSelected: _activeCategoryFilter == entry.key,
              onTap: () {
                setState(() {
                  _activeCategoryFilter = entry.key;
                  if (entry.value.isNotEmpty) {
                    _focusedKey = entry.value.first.key;
                  }
                });
                _listFocusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF3C3C3C) : const Color(0xFF252526),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6E6E6E)
                  : const Color(0xFF333333),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFFE5E5E5)
                  : const Color(0xFF9E9E9E),
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(CatalogExample item) {
    final isSelected = _isSelected(item);
    final isFocused = _focusedKey == item.key;
    final isHovered = _hoveredKey == item.key;
    final (icon, badgeText) = _resolveBadge(item);

    Color bgColor = Colors.transparent;
    if (isSelected) {
      bgColor = const Color(0xFF37373D);
    } else if (isFocused || isHovered) {
      bgColor = const Color(0xFF2A2D2E);
    }

    Color accentColor = Colors.transparent;
    if (isSelected) {
      accentColor = const Color(0xFF38BDF8);
    } else if (isFocused) {
      accentColor = const Color(0xFF6E6E6E);
    }

    return Container(
      key: _keyForItem(item.key),
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
            onTap: () => widget.onSelected(item.mainFile),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  left: BorderSide(color: accentColor, width: 2.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? const Color(0xFFE5E5E5)
                            : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFD4D4D4),
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: const Color(0xFF454545),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 8.5,
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
                            color: Color(0xFF858585),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      item.description.isNotEmpty
                          ? item.description
                          : item.mainFile,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E8E8E),
                        fontSize: 11,
                      ),
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
    String category,
    List<CatalogExample> items,
  ) {
    final categoryTitle = formatCategoryTitle(category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                Text(
                  categoryTitle,
                  key: Key('catalog_category_header_$category'),
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Divider(
                    color: Color(0xFF2D2D2D),
                    height: 1,
                    thickness: 1,
                  ),
                ),
              ],
            ),
          ),
          for (final item in items) _buildListItem(item),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGroups = _groupByCategory();
    final visible = _visibleGroups(allGroups);

    return Focus(
      focusNode: _listFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF212122),
          border: Border(
            right: BorderSide(color: Color(0xFF2D2D2D), width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF252526),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.view_list_rounded,
                    color: Color(0xFFCCCCCC),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Application Catalog',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFD4D4D4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('catalog_dialog_close'),
                    tooltip: 'Close Catalog',
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF9E9E9E),
                      size: 16,
                    ),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),
            _buildCategoryFilterBar(allGroups),
            Expanded(
              child: widget.examples.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No applications available in catalog',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF858585),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in visible.entries)
                            _buildCategorySection(
                              entry.key,
                              entry.value,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
