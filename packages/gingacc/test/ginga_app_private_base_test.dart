import 'package:gingacc/gingacc.dart';
import 'package:test/test.dart';

void main() {
  group('GingaAppPrivateBase', () {
    test('isolates virtual files across distinct application instances',
        () async {
      final gingacc = GingaCC();

      final baseApp1 = GingaAppPrivateBase(
        applicationId: 'app1',
        gingacc: gingacc,
      )..setVirtualFiles({'main.txt': 'Content from App 1'});

      final baseApp2 = GingaAppPrivateBase(
        applicationId: 'app2',
        gingacc: gingacc,
      )..setVirtualFiles({'main.txt': 'Content from App 2'});

      expect(await baseApp1.loadContent('main.txt'), 'Content from App 1');
      expect(await baseApp2.loadContent('main.txt'), 'Content from App 2');
      expect(baseApp1.loadContentSync('main.txt'), 'Content from App 1');
      expect(baseApp2.loadContentSync('main.txt'), 'Content from App 2');
    });

    test(
        'Multi-Instance: two applications run side-by-side with independent private bases and assets',
        () async {
      final gingacc = GingaCC();

      const app1Ncl =
          '<ncl id="app1"><body><media id="img1" src="icon.png"/></body></ncl>';
      const app2Ncl =
          '<ncl id="app2"><body><media id="img2" src="icon.png"/></body></ncl>';

      final pb1 = GingaAppPrivateBase(
        applicationId: 'app1',
        gingacc: gingacc,
      )..setVirtualFiles({
          'app1.ncl': app1Ncl,
          'icon.png': 'app1_icon_bytes',
        });

      final pb2 = GingaAppPrivateBase(
        applicationId: 'app2',
        gingacc: gingacc,
      )..setVirtualFiles({
          'app2.ncl': app2Ncl,
          'icon.png': 'app2_icon_bytes',
        });

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
        'scoped child private base shares virtual files but isolates relative base',
        () async {
      final rootBase = GingaAppPrivateBase(
        applicationId: 'app1',
        baseUri: Uri.file('/app/main.ncl'),
      )..setVirtualFiles({
          '/app/sub/image.png': 'sub-image-bytes',
          '/app/main.ncl': '<ncl></ncl>',
        });

      final childBase = rootBase.scoped(baseDir: 'sub/');

      expect(childBase.applicationId, 'app1');
      expect(await childBase.loadContent('image.png'), 'sub-image-bytes');
    });

    test('GingaCC resolves and loads content directly via virtualFiles',
        () async {
      final gingacc = GingaCC();
      gingacc.setVirtualFiles({'legacy.txt': 'legacy data'});

      expect(await gingacc.loadContent('legacy.txt'), 'legacy data');
      expect(gingacc.loadContentSync('legacy.txt'), 'legacy data');
      expect(gingacc.virtualFiles?['legacy.txt'], 'legacy data');
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

    test('gingacc.getPrivateBase caches per applicationId and inherits virtual files',
        () async {
      final gingacc = GingaCC();
      gingacc.setVirtualFiles({'global.txt': 'hello global'});

      final pbApp1 = gingacc.getPrivateBase(applicationId: 'app1');
      final pbApp1Again = gingacc.getPrivateBase(applicationId: 'app1');
      expect(pbApp1, same(pbApp1Again));
      expect(await pbApp1.loadContent('global.txt'), 'hello global');

      final pbApp2 = gingacc.getPrivateBase(applicationId: 'app2');
      expect(pbApp2, isNot(same(pbApp1)));
      expect(await pbApp2.loadContent('global.txt'), 'hello global');
    });
  });
}
