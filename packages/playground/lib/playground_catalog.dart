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
      return parseCatalog(content);
    }
  } catch (_) {}

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

class CatalogGridView extends StatefulWidget {
  final List<CatalogExample> examples;
  final String? selectedExample;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  const CatalogGridView({
    super.key,
    required this.examples,
    this.selectedExample,
    required this.onSelected,
    required this.onClose,
  });

  @override
  State<CatalogGridView> createState() => _CatalogGridViewState();
}

class _CatalogGridViewState extends State<CatalogGridView> {
  final FocusNode _gridFocusNode = FocusNode();
  final Map<String, GlobalKey> _cardKeys = {};
  String? _activeCategoryFilter;
  String? _focusedKey;
  String? _hoveredKey;
  int _lastCrossAxisCount = 3;

  @override
  void initState() {
    super.initState();
    _initFocus();
  }

  @override
  void didUpdateWidget(covariant CatalogGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.examples != oldWidget.examples && _focusedKey == null) {
      _initFocus();
    }
  }

  @override
  void dispose() {
    _gridFocusNode.dispose();
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

  GlobalKey _keyForCard(String itemKey) {
    return _cardKeys.putIfAbsent(itemKey, () => GlobalKey());
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

  List<List<CatalogExample>> _buildVisualRows(
    Map<String, List<CatalogExample>> groups,
    int crossAxisCount,
  ) {
    final rows = <List<CatalogExample>>[];
    for (final items in groups.values) {
      for (var i = 0; i < items.length; i += crossAxisCount) {
        final end = math.min(i + crossAxisCount, items.length);
        rows.add(items.sublist(i, end));
      }
    }
    return rows;
  }

  (int, int)? _findPosition(List<List<CatalogExample>> rows, String? key) {
    if (key == null) return null;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        if (rows[r][c].key == key) {
          return (r, c);
        }
      }
    }
    return null;
  }

  void _ensureFocusedVisible() {
    final key = _focusedKey;
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _cardKeys[key]?.currentContext;
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
    final rows = _buildVisualRows(visible, _lastCrossAxisCount);
    if (rows.isEmpty) {
      return KeyEventResult.ignored;
    }

    final currentPos = _findPosition(rows, _focusedKey) ?? (0, 0);
    var (r, c) = currentPos;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final selected = rows[r][c];
      widget.onSelected(selected.mainFile);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (c + 1 < rows[r].length) {
        c += 1;
      } else if (r + 1 < rows.length) {
        r += 1;
        c = 0;
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (c - 1 >= 0) {
        c -= 1;
      } else if (r - 1 >= 0) {
        r -= 1;
        c = rows[r].length - 1;
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (r + 1 < rows.length) {
        r += 1;
        c = math.min(c, rows[r].length - 1);
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (r - 1 >= 0) {
        r -= 1;
        c = math.min(c, rows[r].length - 1);
      }
    } else {
      return KeyEventResult.ignored;
    }

    final nextKey = rows[r][c].key;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
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
                _gridFocusNode.requestFocus();
              },
            ),
            for (final entry in allGroups.entries) ...[
              const SizedBox(width: 8),
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
                  _gridFocusNode.requestFocus();
                },
              ),
            ],
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(CatalogExample item) {
    final isSelected = _isSelected(item);
    final isFocused = _focusedKey == item.key;
    final isHovered = _hoveredKey == item.key;
    final (icon, badgeText) = _resolveBadge(item);

    Color borderColor = const Color(0xFF333333);
    double borderWidth = 1.0;
    if (isSelected) {
      borderColor = const Color(0xFFCCCCCC);
      borderWidth = 1.5;
    } else if (isFocused || isHovered) {
      borderColor = const Color(0xFF6E6E6E);
      borderWidth = 1.5;
    }

    Color bgColor = const Color(0xFF252526);
    if (isSelected) {
      bgColor = const Color(0xFF333333);
    } else if (isFocused || isHovered) {
      bgColor = const Color(0xFF2D2D2D);
    }

    return Container(
      key: _keyForCard(item.key),
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
            borderRadius: BorderRadius.circular(6),
            onTap: () => widget.onSelected(item.mainFile),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: 112,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 15,
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
                          style: const TextStyle(
                            color: Color(0xFFD4D4D4),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
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
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      item.description.isNotEmpty
                          ? item.description
                          : item.mainFile,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.mainFile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF757575),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      if (item.otherEditableFiles.isNotEmpty)
                        Text(
                          '+${item.otherEditableFiles.length}',
                          style: const TextStyle(
                            color: Color(0xFF858585),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
    int crossAxisCount,
  ) {
    final categoryTitle = formatCategoryTitle(category);
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += crossAxisCount) {
      final end = math.min(i + crossAxisCount, items.length);
      final chunk = items.sublist(i, end);
      final rowChildren = <Widget>[];
      for (var c = 0; c < crossAxisCount; c++) {
        if (c > 0) {
          rowChildren.add(const SizedBox(width: 12));
        }
        if (c < chunk.length) {
          rowChildren.add(Expanded(child: _buildCard(chunk[c])));
        } else {
          rowChildren.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 12));
      }
      rows.add(Row(children: rowChildren));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  categoryTitle,
                  key: Key('catalog_category_header_$category'),
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
          ...rows,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGroups = _groupByCategory();
    final visible = _visibleGroups(allGroups);

    return Focus(
      focusNode: _gridFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        color: const Color(0xFF1E1E1E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF252526),
                border: Border(
                  top: BorderSide(color: Color(0xFF2D2D2D), width: 1),
                  bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    color: Color(0xFFCCCCCC),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Application Catalog',
                      style: TextStyle(
                        color: Color(0xFFD4D4D4),
                        fontSize: 12.5,
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
                      size: 17,
                    ),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                  ),
                ],
              ),
            ),
            _buildCategoryFilterBar(allGroups),
            Expanded(
              child: widget.examples.isEmpty
                  ? const Center(
                      child: Text(
                        'No applications available in catalog',
                        style: TextStyle(
                          color: Color(0xFF858585),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount =
                            width >= 620 ? 3 : (width >= 380 ? 2 : 1);
                        _lastCrossAxisCount = crossAxisCount;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final entry in visible.entries)
                                _buildCategorySection(
                                  entry.key,
                                  entry.value,
                                  crossAxisCount,
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
    );
  }
}
