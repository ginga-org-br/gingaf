import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:playground/playground.dart';

void main() {
  group('PlaygroundCatalog Unit Tests', () {
    const sampleCatalogJson = '''{
      "examples": {
        "video": {
          "mainFile": "video.ncl",
          "category": "general",
          "description": "Video media presentation example"
        },
        "sbtvd": {
          "mainFile": "sbtvd/main.ncl",
          "category": "general",
          "description": "SBTVD broadcast video example",
          "otherEditbleFiles": [
            "ginga_config.json"
          ]
        },
        "minimal": {
          "mainFile": "minimal.ncl"
        }
      }
    }''';

    test('parseCatalog parses valid JSON into CatalogExample objects', () {
      final examples = parseCatalog(sampleCatalogJson);
      expect(examples.length, equals(3));

      final video = examples.firstWhere((e) => e.key == 'video');
      expect(video.mainFile, equals('video.ncl'));
      expect(video.category, equals('general'));
      expect(video.description, equals('Video media presentation example'));
      expect(video.otherEditableFiles, isEmpty);

      final sbtvd = examples.firstWhere((e) => e.key == 'sbtvd');
      expect(sbtvd.mainFile, equals('sbtvd/main.ncl'));
      expect(sbtvd.otherEditableFiles, contains('ginga_config.json'));

      final minimal = examples.firstWhere((e) => e.key == 'minimal');
      expect(minimal.mainFile, equals('minimal.ncl'));
      expect(minimal.category, equals('general'));
      expect(minimal.description, isEmpty);
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

    test('loadCatalogExamples loads from GingaCC virtualFiles', () async {
      final gingacc = GingaCC();
      gingacc.setVirtualFiles({
        'examples/catalog.json': sampleCatalogJson,
      });

      final examples = await loadCatalogExamples(gingacc: gingacc);
      expect(examples.length, equals(3));
      expect(examples.map((e) => e.key),
          containsAll(['video', 'sbtvd', 'minimal']));
    });

    test('loadExampleContent loads content from GingaCC virtualFiles',
        () async {
      const sampleContent = '<ncl><body/></ncl>';
      final gingacc = GingaCC();
      gingacc.setVirtualFiles({
        'examples/video.ncl': sampleContent,
      });

      final content = await loadExampleContent('video.ncl', gingacc: gingacc);
      expect(content, equals(sampleContent));
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
