import 'package:flutter/material.dart';

class SyntaxHighlighter {
  static const Color defaultColor = Color(0xFFD4D4D4);
  static const Color commentColor = Color(0xFF6A9955);
  static const Color tagDelimiterColor = Color(0xFF808080);
  static const Color tagNameColor = Color(0xFF569CD6);
  static const Color attributeNameColor = Color(0xFF9CDCFE);
  static const Color stringColor = Color(0xFFCE9178);
  static const Color keywordColor = Color(0xFFC586C0);
  static const Color numberColor = Color(0xFFB5CEA8);
  static const Color functionColor = Color(0xFFDCDCAA);
  static const Color typeColor = Color(0xFF4EC9B0);
  static const Color punctuationColor = Color(0xFF808080);

  static const Color currentDebugBg = Color(0x66FFC107);
  static const Color mediaLineBg = Color(0x33FFC107);

  static final RegExp _markupRegex = RegExp(
    r'(<!--[\s\S]*?-->)'
    r'|(<\?[xX][mM][lL][\s\S]*?\?>)'
    r'|(<!DOCTYPE[\s\S]*?>)'
    r'|(<!\[CDATA\[[\s\S]*?\]\]>)'
    r'|(<[/]?[a-zA-Z0-9_\-:]+(?:(?:\s+[^>]*?)|(?:\s*))(/)?>)',
  );

  static final RegExp _tagPartsRegex = RegExp(
    r'(<[/]?)([a-zA-Z0-9_\-:]+)'
    r'|(/?>)'
    r'|([a-zA-Z0-9_\-:]+)(?:(\s*=\s*)("(?:[^"\\]|\\.)*"|\x27(?:[^\x27\\]|\\.)*\x27|[^\s>]+))?',
  );

  static final RegExp _luaRegex = RegExp(
    r'(--\[\[[\s\S]*?\]\])'
    r'|(--[^\n]*)'
    r'|(\[\[[\s\S]*?\]\])'
    r'|("(?:[^"\\]|\\.)*"|\x27(?:[^\x27\\]|\\.)*\x27)'
    r'|(\b(?:0[xX][0-9a-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\b)'
    r'|(\b(?:and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)\b)'
    r'|(\b(?:event|print|math|string|table|os|io|coroutine|debug|type|tostring|tonumber|pairs|ipairs|assert|error|pcall|xpcall|setmetatable|getmetatable|self)\b)'
    r'|(\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\())'
    r'|(==|~=|<=|>=|\.\.|\+|-|\*|/|%|#|[(){}\[\];,])',
  );

  static final RegExp _jsonRegex = RegExp(
    r'("([^"\\]|\\.)*")\s*(:)'
    r'|("([^"\\]|\\.)*")'
    r'|(\b-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)'
    r'|(\b(?:true|false|null)\b)'
    r'|([{}\[\],:])',
  );

  static List<TextSpan> highlight(
    String text, {
    required String language,
    required TextStyle baseStyle,
    int? currentDebugLine,
    Set<int>? highlightedMediaLines,
  }) {
    if (text.isEmpty) return const [];

    final normalized = language.toLowerCase();
    if (normalized == 'ncl' ||
        normalized == 'html' ||
        normalized == 'htm' ||
        normalized == 'xhtml' ||
        normalized == 'xml') {
      return _highlightMarkup(
        text,
        baseStyle,
        currentDebugLine: currentDebugLine,
        highlightedMediaLines: highlightedMediaLines,
      );
    } else if (normalized == 'lua') {
      return _highlightLua(
        text,
        baseStyle,
        currentDebugLine: currentDebugLine,
        highlightedMediaLines: highlightedMediaLines,
      );
    } else if (normalized == 'json') {
      return _highlightJson(
        text,
        baseStyle,
        currentDebugLine: currentDebugLine,
        highlightedMediaLines: highlightedMediaLines,
      );
    }

    return _highlightDefault(
      text,
      baseStyle,
      currentDebugLine: currentDebugLine,
      highlightedMediaLines: highlightedMediaLines,
    );
  }

  static Color? _getLineBackground(
    int line,
    int? currentDebugLine,
    Set<int>? mediaLines,
  ) {
    if (line == currentDebugLine) return currentDebugBg;
    if (mediaLines != null && mediaLines.contains(line)) {
      return mediaLineBg;
    }
    return null;
  }

  static void _addSpan(
    List<TextSpan> spans,
    String spanText,
    Color color,
    TextStyle baseStyle,
    int currentLine,
    int? currentDebugLine,
    Set<int>? mediaLines, {
    FontWeight? fontWeight,
    required void Function(int newLine) onLineAdvanced,
  }) {
    if (spanText.isEmpty) return;
    if (!spanText.contains('\n')) {
      final bg = _getLineBackground(currentLine, currentDebugLine, mediaLines);
      spans.add(TextSpan(
        text: spanText,
        style: baseStyle.copyWith(
          color: color,
          backgroundColor: bg,
          fontWeight: fontWeight,
        ),
      ));
      return;
    }

    final parts = spanText.split('\n');
    var line = currentLine;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        final bg = _getLineBackground(line, currentDebugLine, mediaLines);
        spans.add(TextSpan(
          text: parts[i],
          style: baseStyle.copyWith(
            color: color,
            backgroundColor: bg,
            fontWeight: fontWeight,
          ),
        ));
      }
      if (i < parts.length - 1) {
        final bg = _getLineBackground(line, currentDebugLine, mediaLines);
        spans.add(TextSpan(
          text: '\n',
          style: baseStyle.copyWith(backgroundColor: bg),
        ));
        line++;
        onLineAdvanced(line);
      }
    }
  }

  static List<TextSpan> _highlightMarkup(
    String text,
    TextStyle baseStyle, {
    int? currentDebugLine,
    Set<int>? highlightedMediaLines,
  }) {
    final spans = <TextSpan>[];
    var currentLine = 1;

    void add(String s, Color c, {FontWeight? fw}) {
      _addSpan(
        spans,
        s,
        c,
        baseStyle,
        currentLine,
        currentDebugLine,
        highlightedMediaLines,
        fontWeight: fw,
        onLineAdvanced: (l) => currentLine = l,
      );
    }

    int lastIndex = 0;
    for (final m in _markupRegex.allMatches(text)) {
      if (m.start > lastIndex) {
        add(text.substring(lastIndex, m.start), defaultColor);
      }

      final matchText = m.group(0)!;
      if (m.group(1) != null) {
        add(matchText, commentColor);
      } else if (m.group(2) != null || m.group(3) != null) {
        add(matchText, punctuationColor);
      } else if (m.group(4) != null) {
        add(matchText, typeColor);
      } else {
        int tagLast = 0;
        for (final tm in _tagPartsRegex.allMatches(matchText)) {
          if (tm.start > tagLast) {
            add(matchText.substring(tagLast, tm.start), defaultColor);
          }
          if (tm.group(1) != null) {
            add(tm.group(1)!, tagDelimiterColor);
            add(tm.group(2)!, tagNameColor);
          } else if (tm.group(3) != null) {
            add(tm.group(3)!, tagDelimiterColor);
          } else if (tm.group(4) != null) {
            add(tm.group(4)!, attributeNameColor);
            if (tm.group(5) != null) {
              add(tm.group(5)!, punctuationColor);
            }
            if (tm.group(6) != null) {
              add(tm.group(6)!, stringColor);
            }
          }
          tagLast = tm.end;
        }
        if (tagLast < matchText.length) {
          add(matchText.substring(tagLast), defaultColor);
        }
      }
      lastIndex = m.end;
    }

    if (lastIndex < text.length) {
      add(text.substring(lastIndex), defaultColor);
    }

    return spans;
  }

  static List<TextSpan> _highlightLua(
    String text,
    TextStyle baseStyle, {
    int? currentDebugLine,
    Set<int>? highlightedMediaLines,
  }) {
    final spans = <TextSpan>[];
    var currentLine = 1;

    void add(String s, Color c, {FontWeight? fw}) {
      _addSpan(
        spans,
        s,
        c,
        baseStyle,
        currentLine,
        currentDebugLine,
        highlightedMediaLines,
        fontWeight: fw,
        onLineAdvanced: (l) => currentLine = l,
      );
    }

    int lastIndex = 0;
    for (final m in _luaRegex.allMatches(text)) {
      if (m.start > lastIndex) {
        add(text.substring(lastIndex, m.start), defaultColor);
      }
      final matchText = m.group(0)!;
      if (m.group(1) != null || m.group(2) != null) {
        add(matchText, commentColor);
      } else if (m.group(3) != null || m.group(4) != null) {
        add(matchText, stringColor);
      } else if (m.group(5) != null) {
        add(matchText, numberColor);
      } else if (m.group(6) != null) {
        add(matchText, keywordColor, fw: FontWeight.bold);
      } else if (m.group(7) != null) {
        add(matchText, functionColor);
      } else if (m.group(8) != null) {
        add(matchText, functionColor);
      } else if (m.group(9) != null) {
        add(matchText, punctuationColor);
      }
      lastIndex = m.end;
    }

    if (lastIndex < text.length) {
      add(text.substring(lastIndex), defaultColor);
    }

    return spans;
  }

  static List<TextSpan> _highlightJson(
    String text,
    TextStyle baseStyle, {
    int? currentDebugLine,
    Set<int>? highlightedMediaLines,
  }) {
    final spans = <TextSpan>[];
    var currentLine = 1;

    void add(String s, Color c, {FontWeight? fw}) {
      _addSpan(
        spans,
        s,
        c,
        baseStyle,
        currentLine,
        currentDebugLine,
        highlightedMediaLines,
        fontWeight: fw,
        onLineAdvanced: (l) => currentLine = l,
      );
    }

    int lastIndex = 0;
    for (final m in _jsonRegex.allMatches(text)) {
      if (m.start > lastIndex) {
        add(text.substring(lastIndex, m.start), defaultColor);
      }
      if (m.group(1) != null) {
        add(m.group(1)!, attributeNameColor);
        if (m.group(3) != null) {
          add(m.group(3)!, punctuationColor);
        }
      } else if (m.group(4) != null) {
        add(m.group(4)!, stringColor);
      } else if (m.group(6) != null) {
        add(m.group(6)!, numberColor);
      } else if (m.group(7) != null) {
        add(m.group(7)!, tagNameColor);
      } else if (m.group(8) != null) {
        add(m.group(8)!, punctuationColor);
      }
      lastIndex = m.end;
    }

    if (lastIndex < text.length) {
      add(text.substring(lastIndex), defaultColor);
    }

    return spans;
  }

  static List<TextSpan> _highlightDefault(
    String text,
    TextStyle baseStyle, {
    int? currentDebugLine,
    Set<int>? highlightedMediaLines,
  }) {
    final spans = <TextSpan>[];
    var currentLine = 1;

    _addSpan(
      spans,
      text,
      defaultColor,
      baseStyle,
      currentLine,
      currentDebugLine,
      highlightedMediaLines,
      onLineAdvanced: (l) => currentLine = l,
    );

    return spans;
  }
}
