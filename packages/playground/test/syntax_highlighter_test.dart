import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playground/playground.dart';

void main() {
  group('SyntaxHighlighter Unit Tests', () {
    const baseStyle = TextStyle(fontFamily: 'monospace', fontSize: 13);

    test('highlights NCL markup tags, attributes, strings, and comments', () {
      const nclCode = '''<!-- comment -->
<ncl id="app">
  <media id="m1" src="test.mp4"/>
</ncl>''';

      final spans = SyntaxHighlighter.highlight(
        nclCode,
        language: 'ncl',
        baseStyle: baseStyle,
      );

      expect(spans, isNotEmpty);
      final hasComment = spans.any((s) =>
          s.text?.contains('comment') == true &&
          s.style?.color == SyntaxHighlighter.commentColor);
      final hasTagName = spans.any((s) =>
          s.text == 'ncl' && s.style?.color == SyntaxHighlighter.tagNameColor);
      final hasAttr = spans.any((s) =>
          s.text == 'id' &&
          s.style?.color == SyntaxHighlighter.attributeNameColor);
      final hasString = spans.any((s) =>
          s.text == '"app"' &&
          s.style?.color == SyntaxHighlighter.stringColor);

      expect(hasComment, isTrue);
      expect(hasTagName, isTrue);
      expect(hasAttr, isTrue);
      expect(hasString, isTrue);
    });

    test('highlights HTML markup', () {
      const htmlCode = '<div class="container"><p>Hello</p></div>';
      final spans = SyntaxHighlighter.highlight(
        htmlCode,
        language: 'html',
        baseStyle: baseStyle,
      );

      expect(spans, isNotEmpty);
      final hasDiv = spans.any((s) =>
          s.text == 'div' && s.style?.color == SyntaxHighlighter.tagNameColor);
      final hasClass = spans.any((s) =>
          s.text == 'class' &&
          s.style?.color == SyntaxHighlighter.attributeNameColor);
      final hasString = spans.any((s) =>
          s.text == '"container"' &&
          s.style?.color == SyntaxHighlighter.stringColor);

      expect(hasDiv, isTrue);
      expect(hasClass, isTrue);
      expect(hasString, isTrue);
    });

    test('highlights Lua keywords, strings, numbers, and comments', () {
      const luaCode = '''-- lua test
local count = 42
function greet(name)
  print("Hello " .. name)
  return true
end''';

      final spans = SyntaxHighlighter.highlight(
        luaCode,
        language: 'lua',
        baseStyle: baseStyle,
      );

      expect(spans, isNotEmpty);
      final hasComment = spans.any((s) =>
          s.text?.contains('lua test') == true &&
          s.style?.color == SyntaxHighlighter.commentColor);
      final hasKeyword = spans.any((s) =>
          (s.text == 'local' || s.text == 'function' || s.text == 'return') &&
          s.style?.color == SyntaxHighlighter.keywordColor);
      final hasNumber = spans.any((s) =>
          s.text == '42' && s.style?.color == SyntaxHighlighter.numberColor);
      final hasString = spans.any((s) =>
          s.text == '"Hello "' &&
          s.style?.color == SyntaxHighlighter.stringColor);
      final hasBuiltin = spans.any((s) =>
          s.text == 'print' &&
          s.style?.color == SyntaxHighlighter.functionColor);

      expect(hasComment, isTrue);
      expect(hasKeyword, isTrue);
      expect(hasNumber, isTrue);
      expect(hasString, isTrue);
      expect(hasBuiltin, isTrue);
    });

    test('highlights JSON keys, values, and numbers', () {
      const jsonCode = '{"name": "test", "count": 10, "enabled": true}';
      final spans = SyntaxHighlighter.highlight(
        jsonCode,
        language: 'json',
        baseStyle: baseStyle,
      );

      expect(spans, isNotEmpty);
      final hasKey = spans.any((s) =>
          s.text == '"name"' &&
          s.style?.color == SyntaxHighlighter.attributeNameColor);
      final hasString = spans.any((s) =>
          s.text == '"test"' &&
          s.style?.color == SyntaxHighlighter.stringColor);
      final hasNumber = spans.any((s) =>
          s.text == '10' && s.style?.color == SyntaxHighlighter.numberColor);

      expect(hasKey, isTrue);
      expect(hasString, isTrue);
      expect(hasNumber, isTrue);
    });
  });

  group('PlaygroundTextEditingController syntax & debug integration', () {
    testWidgets('switches language and colors tokens accordingly',
        (WidgetTester tester) async {
      final controller = PlaygroundTextEditingController(
        text: '<ncl id="app"/>',
        language: 'ncl',
      );

      final span = controller.buildTextSpan(
        context: tester.binding.rootElement!,
        withComposing: false,
      );

      expect(span.children, isNotEmpty);
      final line1 = span.children!.first as TextSpan;
      expect(line1.children, isNotEmpty);

      controller.language = 'lua';
      controller.text = 'local x = 10';
      final luaSpan = controller.buildTextSpan(
        context: tester.binding.rootElement!,
        withComposing: false,
      );
      final luaLine1 = luaSpan.children!.first as TextSpan;
      final hasLocal = luaLine1.children!.whereType<TextSpan>().any((s) =>
          s.text == 'local' &&
          s.style?.color == SyntaxHighlighter.keywordColor);
      expect(hasLocal, isTrue);
    });
  });

  group('Word Wrap in PlaygroundEditor', () {
    testWidgets('renders long text with word wrap and expanded gutter height',
        (WidgetTester tester) async {
      final veryLongLine =
          '<media id="very_long_media_element_with_many_attributes" ' * 10 + '/>';
      final content = '<ncl>\n$veryLongLine\n</ncl>';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: PlaygroundEditor(
                content: content,
                filePath: 'wrap_test.ncl',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('monaco_editor_text_field')), findsOneWidget);
      expect(find.byKey(const Key('monaco_gutter_line_1')), findsOneWidget);
      expect(find.byKey(const Key('monaco_gutter_line_2')), findsOneWidget);
      expect(find.byKey(const Key('monaco_gutter_line_3')), findsOneWidget);

      final line1Box = tester.getRect(find.byKey(const Key('monaco_gutter_line_1')));
      final line2Box = tester.getRect(find.byKey(const Key('monaco_gutter_line_2')));

      expect(line1Box.height, equals(20.0));
      expect(line2Box.height, greaterThan(20.0));
    });
  });
}
