import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:playground/playground.dart';

void main() {
  group('PlaygroundCatalog Unit Tests', () {
    const sampleCatalogJson = '''{
      "examples": {
        "video": {
          "mainFile": "video.ncl",
          "type": "NCL",
          "category": "general",
          "description": "Video media presentation example"
        },
        "sbtvd": {
          "mainFile": "sbtvd/main.ncl",
          "type": "NCL",
          "category": "general",
          "description": "SBTVD broadcast video example",
          "otherEditbleFiles": [
            "ginga_config.json"
          ]
        },
        "html_demo": {
          "mainFile": "image.html",
          "type": "HTML",
          "category": "general",
          "description": "HTML demo"
        },
        "minimal": {
          "mainFile": "minimal.ncl"
        }
      }
    }''';

    tearDown(() {
      catalogExamplesBaseUrl = defaultCatalogExamplesBaseUrl;
    });

    test('parseCatalog parses valid JSON into CatalogExample objects', () {
      final examples = parseCatalog(sampleCatalogJson);
      expect(examples.length, equals(4));

      final video = examples.firstWhere((e) => e.key == 'video');
      expect(video.mainFile, equals('video.ncl'));
      expect(video.type, equals('NCL'));
      expect(video.category, equals('general'));
      expect(video.description, equals('Video media presentation example'));
      expect(video.otherEditableFiles, isEmpty);

      final sbtvd = examples.firstWhere((e) => e.key == 'sbtvd');
      expect(sbtvd.mainFile, equals('sbtvd/main.ncl'));
      expect(sbtvd.type, equals('NCL'));
      expect(sbtvd.otherEditableFiles, contains('ginga_config.json'));

      final htmlDemo = examples.firstWhere((e) => e.key == 'html_demo');
      expect(htmlDemo.mainFile, equals('image.html'));
      expect(htmlDemo.type, equals('HTML'));
      expect(htmlDemo.category, equals('general'));

      final minimal = examples.firstWhere((e) => e.key == 'minimal');
      expect(minimal.mainFile, equals('minimal.ncl'));
      expect(minimal.type, equals('NCL'));
      expect(minimal.category, equals('general'));
      expect(minimal.description, isEmpty);
    });

    test(
        'loadCatalogExamples fetches default catalog URL with NCL and HTML types',
        () async {
      final parsed = await loadCatalogExamples();
      expect(parsed, isNotEmpty);
      for (final item in parsed) {
        expect(item.type, isIn(['NCL', 'HTML']));
      }
      expect(parsed.any((e) => e.type == 'NCL'), isTrue);
      expect(parsed.any((e) => e.type == 'HTML'), isTrue);
    });

    test('parseCatalog returns empty list for invalid or empty input', () {
      expect(parseCatalog(''), isEmpty);
      expect(parseCatalog('invalid json'), isEmpty);
      expect(parseCatalog({}), isEmpty);
      expect(parseCatalog({'examples': 'not a map'}), isEmpty);
    });

    test('loadCatalogExamples loads from customCatalogData', () async {
      final examples = await loadCatalogExamples(
        customCatalogData: {
          'examples': {
            'test': {
              'mainFile': 'test.ncl',
              'description': 'Test Example',
            }
          }
        },
      );
      expect(examples.length, equals(1));
      expect(examples.first.key, equals('test'));
      expect(examples.first.mainFile, equals('test.ncl'));
      expect(examples.first.description, equals('Test Example'));
    });

    test('loadCatalogExamples and loadExampleContent fetch over HTTP URL',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((req) {
        if (req.uri.path == '/examples/catalog.json') {
          req.response
            ..statusCode = 200
            ..write(sampleCatalogJson);
        } else if (req.uri.path == '/examples/video.ncl') {
          req.response
            ..statusCode = 200
            ..write('<ncl id="http_video"/>');
        } else {
          req.response.statusCode = 404;
        }
        req.response.close();
      });

      catalogExamplesBaseUrl = 'http://127.0.0.1:${server.port}/examples';
      final gingacc = GingaCC();
      final examples = await loadCatalogExamples(gingacc: gingacc);
      expect(examples.length, equals(4));
      expect(examples.map((e) => e.key),
          containsAll(['video', 'sbtvd', 'html_demo', 'minimal']));

      final content = await loadExampleContent('video.ncl', gingacc: gingacc);
      expect(content, equals('<ncl id="http_video"/>'));
    });

    test('resolveCatalogExampleUrl resolves catalog entries to GitHub URL', () {
      expect(
        resolveCatalogExampleUrl('catalog.json'),
        'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/catalog.json',
      );
      expect(
        resolveCatalogExampleUrl('sbtvd/main.ncl'),
        'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/sbtvd/main.ncl',
      );
      expect(
        resolveCatalogExampleUrl('examples/video.ncl'),
        'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl',
      );
      expect(
        resolveCatalogExampleUrl('https://custom.org/app.ncl'),
        'https://custom.org/app.ncl',
      );
    });
  });
}
