import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/ncl_widget.dart';

class _TestMediaWidget extends BaseWidget {
  const _TestMediaWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
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

        final opacityBefore = tester.widget<Opacity>(
          find.descendant(of: find.byKey(key), matching: find.byType(Opacity)),
        );
        expect(opacityBefore.opacity, closeTo(128 / 255.0, 0.01));

        state.clearMedia();
        await tester.pump();

        expect(state.alpha, equals(255));
        expect(state.background, equals(Colors.transparent));
        expect(state.focusBorderColor, equals(Colors.transparent));
        expect(state.focusBorderWidth, equals(0));
        expect(state.focusBorderTransparency, equals(0));
        expect(state.selBorderColor, equals(Colors.transparent));
        expect(state.soundLevel, equals(1.0));

        final opacityAfter = tester.widget<Opacity>(
          find.descendant(of: find.byKey(key), matching: find.byType(Opacity)),
        );
        expect(opacityAfter.opacity, equals(1.0));
      },
    );

    testWidgets(
      'applies descriptor transparency to Opacity widget and handles selection tap',
      (tester) async {
        const nclSrc = '''
<ncl>
  <head>
    <regionBase>
      <region id="r1" left="0%" top="0%" width="50%" height="50%"/>
      <region id="r2" left="50%" top="0%" width="50%" height="50%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="d1" region="r1" focusIndex="1"/>
      <descriptor id="d2" region="r2" focusIndex="2">
        <descriptorParam name="transparency" value="25%"/>
      </descriptor>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onSelectionSet">
        <connectorParam name="val"/>
        <simpleCondition role="onSelection"/>
        <simpleAction role="set" value="\$val"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="btn1"/>
    <port id="p2" component="btn2"/>
    <media id="btn1" descriptor="d1"/>
    <media id="btn2" descriptor="d2">
      <property name="background" value="blue"/>
    </media>
    <link xconnector="onSelectionSet">
      <bind role="onSelection" component="btn2"/>
      <bind role="set" component="btn2" interface="background">
        <bindParam name="val" value="gold"/>
      </bind>
    </link>
  </body>
</ncl>
''';
        final doc = NclDocument.fromContent(nclSrc, appSrc: 'tap_test.ncl');
        doc.start();
        doc.scheduler.tick(100);
        expect(doc.currentFocusNodeId, equals('btn1'));

        final btn2Media = doc.getNodeById('btn2') as Media;
        final key = GlobalKey<_TestMediaWidgetState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: Stack(
                  children: [
                    _TestMediaWidget(
                      key: key,
                      src: '',
                      media: btn2Media,
                      document: doc,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final opacityWidget = tester.widget<Opacity>(
          find.descendant(of: find.byKey(key), matching: find.byType(Opacity)),
        );
        expect(opacityWidget.opacity, closeTo(0.75, 0.01));

        await tester.tap(find.byKey(key));
        await tester.pump();

        expect(doc.currentFocusNodeId, equals('btn2'));
        final bgProp = btn2Media
            .getProperties()
            .firstWhere((p) => p.name == 'background')
            .value;
        expect(bgProp, equals('gold'));
      },
    );
  });
}
