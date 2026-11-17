import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/ncl.dart';

class _TestMediaWidget extends BaseWidget {
  const _TestMediaWidget({
    super.key,
    required super.src,
    super.media,
  });

  @override
  State<_TestMediaWidget> createState() => _TestMediaWidgetState();
}

class _TestMediaWidgetState extends MediaState<_TestMediaWidget> {
  @override
  Widget buildWidgetContent(BuildContext context) {
    return const SizedBox(width: 20, height: 20);
  }
}

void main() {
  group('Centralized NCL/CSS Color & Transparency Parsing (color.dart)', () {
    test('parses 3-, 4-, 6-, and 8-digit hex colors accurately', () {
      expect(parseNclColor('#F0A'), equals(const Color(0xFFFF00AA)));
      expect(parseNclColor('#0F08'), equals(const Color(0x8800FF00)));
      expect(parseNclColor('#123456'), equals(const Color(0xFF123456)));
      expect(parseNclColor('#FF000080'), equals(const Color(0x80FF0000)));
      expect(tryParseNclColor('#ZZZZZZ'), isNull);
      expect(parseNclColor(''), equals(Colors.transparent));
    });

    test('parses rgb() and rgba() with integer and percentage channels', () {
      expect(
        parseNclColor('rgb(255, 0, 128)'),
        equals(const Color(0xFFFF0080)),
      );
      expect(
        parseNclColor('rgb(100%, 50%, 0%)'),
        equals(const Color(0xFFFF8000)),
      );
      expect(
        parseNclColor('rgba(0, 255, 0, 0.5)'),
        equals(const Color(0x8000FF00)),
      );
      expect(
        parseNclColor('rgba(0, 0, 255, 50%)'),
        equals(const Color(0x800000FF)),
      );
    });

    test('parses standard W3C/NCL named colors', () {
      expect(parseNclColor('transparent'), equals(Colors.transparent));
      expect(parseNclColor('red'), equals(Colors.red));
      expect(parseNclColor('silver'), equals(const Color(0xFFC0C0C0)));
      expect(parseNclColor('maroon'), equals(const Color(0xFF800000)));
      expect(parseNclColor('fuchsia'), equals(const Color(0xFFFF00FF)));
      expect(parseNclColor('navy'), equals(const Color(0xFF000080)));
      expect(parseNclColor('olive'), equals(const Color(0xFF808000)));
      expect(parseNclColor('gold'), equals(const Color(0xFFFFD700)));
    });

    test('parses transparency and alpha values', () {
      expect(tryParseNclTransparencyToAlpha('0%'), equals(255));
      expect(tryParseNclTransparencyToAlpha('50%'), equals(128));
      expect(tryParseNclTransparencyToAlpha('100%'), equals(0));
      expect(tryParseNclTransparencyToAlpha('0.25'), equals(191));
      expect(tryParseNclAlpha('50%'), equals(128));
      expect(tryParseNclAlpha('200'), equals(200));
    });
  });

  group('BaseWidget & MediaState properties and lifecycle', () {
    testWidgets(
      'parses background, transparency, focusBorderTransparency, and resets on clearMedia',
      (tester) async {
        final key = GlobalKey<_TestMediaWidgetState>();
        final media = Media(
          rawAttributes: {
            'id': 'm1',
            'focusBorderColor': '#FF0000',
            'focusBorderWidth': '6',
            'focusBorderTransparency': '50%',
            'selBorderColor': '#00FF00',
          },
        );
        media.setPropertyValue('background', '#112233');
        media.setPropertyValue('transparency', '50%');
        media.setPropertyValue('soundLevel', '75%');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  _TestMediaWidget(
                    key: key,
                    src: 'test.png',
                    media: media,
                  ),
                ],
              ),
            ),
          ),
        );

        final state = key.currentState!;
        expect(state.background, equals(const Color(0xFF112233)));
        expect(state.alpha, equals(128));
        expect(state.focusBorderWidth, equals(6));
        expect(state.focusBorderColor.a, closeTo(128 / 255.0, 0.01));
        expect(state.selBorderColor, equals(const Color(0xFF00FF00)));
        expect(state.soundLevel, closeTo(0.75, 0.001));

        state.clearMedia();
        expect(state.alpha, equals(255));
        expect(state.background, equals(Colors.transparent));
        expect(state.focusBorderColor, equals(Colors.transparent));
        expect(state.focusBorderWidth, equals(0));
        expect(state.focusBorderTransparency, equals(0));
        expect(state.selBorderColor, equals(Colors.transparent));
        expect(state.soundLevel, equals(1.0));
      },
    );
  });
}
