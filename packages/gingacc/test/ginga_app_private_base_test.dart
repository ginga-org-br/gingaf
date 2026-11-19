import 'dart:io';

import 'package:gingacc/gingacc.dart';
import 'package:test/test.dart';

void main() {
  group('GingaAppPrivateBase', () {
    test('isolates virtualFiles across distinct application instances',
        () async {
      final gingacc = GingaCC();

      final baseApp1 = gingacc.getPrivateBase(
        applicationId: 'app1',
        virtualFiles: {'main.txt': 'Content from App 1'},
      );

      final baseApp2 = gingacc.getPrivateBase(
        applicationId: 'app2',
        virtualFiles: {'main.txt': 'Content from App 2'},
      );

      expect(await baseApp1.loadContent('main.txt'), 'Content from App 1');
      expect(await baseApp2.loadContent('main.txt'), 'Content from App 2');
      expect(baseApp1.loadContentSync('main.txt'), 'Content from App 1');
      expect(baseApp2.loadContentSync('main.txt'), 'Content from App 2');
      expect(await gingacc.loadContent('main.txt'), isNull);
    });

    test(
        'Multi-Instance: two applications run side-by-side with independent private bases and assets',
        () async {
      final gingacc = GingaCC();

      const app1Ncl =
          '<ncl id="app1"><body><media id="img1" src="icon.png"/></body></ncl>';
      const app2Ncl =
          '<ncl id="app2"><body><media id="img2" src="icon.png"/></body></ncl>';

      final pb1 = gingacc.getPrivateBase(
        applicationId: 'app1',
        virtualFiles: {
          'app1.ncl': app1Ncl,
          'icon.png': 'app1_icon_bytes',
        },
      );

      final pb2 = gingacc.getPrivateBase(
        applicationId: 'app2',
        virtualFiles: {
          'app2.ncl': app2Ncl,
          'icon.png': 'app2_icon_bytes',
        },
      );

      expect(pb1.applicationId, 'app1');
      expect(pb2.applicationId, 'app2');

      expect(await pb1.loadContent('app1.ncl'), app1Ncl);
      expect(await pb2.loadContent('app2.ncl'), app2Ncl);

      expect(await pb1.loadContent('icon.png'), 'app1_icon_bytes');
      expect(await pb2.loadContent('icon.png'), 'app2_icon_bytes');

      expect(await pb1.loadContent('app2.ncl'), isNull);
      expect(await pb2.loadContent('app1.ncl'), isNull);
    });

    test(
        'scoped child private base shares virtualFiles and isolates relative subdirectory base',
        () async {
      final rootBase = GingaAppPrivateBase(
        applicationId: 'app1',
        baseUri: Uri.file('/app/main.ncl'),
        virtualFiles: {
          '/app/sub/image.png': 'sub-image-bytes',
          '/app/main.ncl': '<ncl></ncl>',
        },
      );

      final childBase = rootBase.scoped(baseDir: 'sub/');

      expect(childBase.applicationId, 'app1');
      expect(await childBase.loadContent('image.png'), 'sub-image-bytes');
    });

    test('resolves same filename in different folders without collision',
        () async {
      final pb = GingaAppPrivateBase(
        applicationId: 'multi_dir',
        baseUri: Uri.parse('https://example.org/examples/dirA/main.ncl'),
        virtualFiles: {
          'dirA/main.ncl': '<ncl id="A"/>',
          'dirB/main.ncl': '<ncl id="B"/>',
        },
      );

      expect(await pb.loadContent('main.ncl'), '<ncl id="A"/>');
      final scopedB = pb.scoped(
        baseUri: Uri.parse('https://example.org/examples/dirB/main.ncl'),
      );
      expect(await scopedB.loadContent('main.ncl'), '<ncl id="B"/>');
    });

    test('loads real files from temporary directory via baseUri', () async {
      final tempDir = Directory.systemTemp.createTempSync('ginga_pb_disk_');
      try {
        File('${tempDir.path}/asset.txt').writeAsStringSync('disk_asset');
        final pb = GingaAppPrivateBase(
          applicationId: 'disk_app',
          baseUri: tempDir.uri,
        );
        expect(await pb.loadContent('asset.txt'), 'disk_asset');
        expect(pb.loadContentSync('asset.txt'), 'disk_asset');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('GingaApp obtains privateBase from gingacc and uses appSrc', () async {
      final gingacc = GingaCC();
      final app = GingaApp(
        appSrc: 'main.ncl',
        gingacc: gingacc,
      );

      expect(app.appSrc, 'main.ncl');
      expect(app.applicationId, 'main.ncl');
      expect(app.privateBase,
          same(gingacc.getPrivateBase(applicationId: 'main.ncl')));
      expect(app.privateBase.applicationId, 'main.ncl');
    });

    test('gingacc.getPrivateBase caches per applicationId and cleans up',
        () async {
      final gingacc = GingaCC();
      final pbApp1 = gingacc.getPrivateBase(
        applicationId: 'app1',
        virtualFiles: {'a.txt': 'v1'},
      );
      final pbApp1Again = gingacc.getPrivateBase(applicationId: 'app1');
      expect(pbApp1, same(pbApp1Again));
      expect(pbApp1Again.virtualFiles?['a.txt'], 'v1');

      final pbApp2 = gingacc.getPrivateBase(applicationId: 'app2');
      expect(pbApp2, isNot(same(pbApp1)));
      expect(pbApp2.virtualFiles, isNull);

      gingacc.removePrivateBase('app1');
      final pbApp1Recreated = gingacc.getPrivateBase(applicationId: 'app1');
      expect(pbApp1Recreated, isNot(same(pbApp1)));
      expect(pbApp1Recreated.virtualFiles, isNull);
    });
  });
}
