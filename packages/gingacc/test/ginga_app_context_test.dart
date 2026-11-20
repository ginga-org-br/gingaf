import 'dart:convert';
import 'dart:io';

import 'package:gingacc/gingacc.dart';
import 'package:test/test.dart';

void main() {
  group('GingaAppContext', () {
    test('isolates virtualFiles across distinct application instances',
        () async {
      final gingacc = GingaCC();

      final ctxApp1 = gingacc.getAppContext(
        appContextId: 'app1',
        virtualFiles: {'main.txt': 'Content from App 1'},
      );

      final ctxApp2 = gingacc.getAppContext(
        appContextId: 'app2',
        virtualFiles: {'main.txt': 'Content from App 2'},
      );

      expect(await ctxApp1.loadContent('main.txt'), 'Content from App 1');
      expect(await ctxApp2.loadContent('main.txt'), 'Content from App 2');
      expect(ctxApp1.loadContentSync('main.txt'), 'Content from App 1');
      expect(ctxApp2.loadContentSync('main.txt'), 'Content from App 2');
      expect(await gingacc.loadContent('main.txt'), isNull);
    });

    test(
        'Multi-Instance: two applications run side-by-side with independent app contexts and assets',
        () async {
      final gingacc = GingaCC();

      const app1Html = '<html><body><img src="icon.png"/></body></html>';
      const app2Ncl =
          '<ncl id="app2"><body><media id="img2" src="icon.png"/></body></ncl>';

      final ctx1 = gingacc.getAppContext(
        appContextId: 'app1',
        virtualFiles: {
          'index.html': app1Html,
          'icon.png': 'app1_icon_bytes',
        },
      );

      final ctx2 = gingacc.getAppContext(
        appContextId: 'app2',
        virtualFiles: {
          'app2.ncl': app2Ncl,
          'icon.png': 'app2_icon_bytes',
        },
      );

      expect(ctx1.appContextId, 'app1');
      expect(ctx1.applicationId, 'app1');
      expect(ctx2.appContextId, 'app2');

      expect(await ctx1.loadContent('index.html'), app1Html);
      expect(await ctx2.loadContent('app2.ncl'), app2Ncl);

      expect(await ctx1.loadContent('icon.png'), 'app1_icon_bytes');
      expect(await ctx2.loadContent('icon.png'), 'app2_icon_bytes');

      expect(await ctx1.loadContent('app2.ncl'), isNull);
      expect(await ctx2.loadContent('index.html'), isNull);
    });

    test(
        'scoped child context shares virtualFiles and isolates relative subdirectory base',
        () async {
      final rootCtx = GingaAppContext(
        appContextId: 'app1',
        baseUri: Uri.file('/app/main.ncl'),
        virtualFiles: {
          '/app/sub/image.png': 'sub-image-bytes',
          '/app/main.ncl': '<ncl></ncl>',
        },
      );

      final childCtx = rootCtx.scoped(baseDir: 'sub/');

      expect(childCtx.appContextId, 'app1');
      expect(await childCtx.loadContent('image.png'), 'sub-image-bytes');
    });

    test('resolves same filename in different folders without collision',
        () async {
      final ctx = GingaAppContext(
        appContextId: 'multi_dir',
        baseUri: Uri.parse('https://example.org/examples/dirA/main.ncl'),
        virtualFiles: {
          'dirA/main.ncl': '<ncl id="A"/>',
          'dirB/main.ncl': '<ncl id="B"/>',
        },
      );

      expect(await ctx.loadContent('main.ncl'), '<ncl id="A"/>');
      final scopedB = ctx.scoped(
        baseUri: Uri.parse('https://example.org/examples/dirB/main.ncl'),
      );
      expect(await scopedB.loadContent('main.ncl'), '<ncl id="B"/>');
    });

    test('loads real files from temporary directory via baseUri', () async {
      final tempDir = Directory.systemTemp.createTempSync('ginga_ctx_disk_');
      try {
        File('${tempDir.path}/asset.txt').writeAsStringSync('disk_asset');
        final ctx = GingaAppContext(
          appContextId: 'disk_app',
          baseUri: tempDir.uri,
        );
        expect(await ctx.loadContent('asset.txt'), 'disk_asset');
        expect(ctx.loadContentSync('asset.txt'), 'disk_asset');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('GingaApp obtains appContext from gingacc and uses appSrc', () {
      final gingacc = GingaCC();
      final app = GingaApp(
        appSrc: 'index.html',
        gingacc: gingacc,
      );

      expect(app.appSrc, 'index.html');
      expect(app.applicationId, 'index.html');
      expect(app.appContextId, 'index.html');
      expect(
        app.appContext,
        same(gingacc.getAppContext(appContextId: 'index.html')),
      );
      expect(app.appContext.appContextId, 'index.html');
    });

    test('gingacc.getAppContext caches per appContextId and cleans up', () {
      final gingacc = GingaCC();
      final ctxApp1 = gingacc.getAppContext(
        appContextId: 'app1',
        virtualFiles: {'a.txt': 'v1'},
      );
      final ctxApp1Again = gingacc.getAppContext(appContextId: 'app1');
      expect(ctxApp1, same(ctxApp1Again));
      expect(ctxApp1Again.virtualFiles?['a.txt'], 'v1');
      expect(gingacc.hasAppContext('app1'), isTrue);
      expect(gingacc.findAppContext('app1'), same(ctxApp1));
      expect(gingacc.appContextIds, contains('app1'));

      final ctxApp2 = gingacc.getAppContext(appContextId: 'app2');
      expect(ctxApp2, isNot(same(ctxApp1)));
      expect(ctxApp2.virtualFiles, isNull);

      gingacc.removeAppContext('app1');
      expect(gingacc.hasAppContext('app1'), isFalse);
      expect(gingacc.findAppContext('app1'), isNull);
      final ctxApp1Recreated = gingacc.getAppContext(appContextId: 'app1');
      expect(ctxApp1Recreated, isNot(same(ctxApp1)));
      expect(ctxApp1Recreated.virtualFiles, isNull);
    });

    test('virtual entry write, list, exists, and deletion work cleanly', () {
      final ctx = GingaAppContext(
        appContextId: 'ctx_virtual',
        virtualFiles: {
          'assets/data.txt': 'hello',
          'notes.txt': 'world',
        },
      );

      expect(ctx.existsSync('notes.txt'), isTrue);
      expect(ctx.existsSync('missing.txt'), isFalse);
      expect(ctx.listEntriesSync(), ['assets/data.txt', 'notes.txt']);
      expect(ctx.listEntriesSync('assets'), ['data.txt']);

      expect(
        ctx.writeBytesSync(
          'saved.json',
          utf8.encode('{"ok":true}'),
          mimeType: 'application/json',
        ),
        isTrue,
      );
      expect(ctx.loadContentSync('saved.json'), '{"ok":true}');

      expect(ctx.removeEntrySync('notes.txt'), isTrue);
      expect(ctx.existsSync('notes.txt'), isFalse);
    });

    test('entry listing and deletion work on real filesystem directory', () {
      final tempDir = Directory.systemTemp.createTempSync('ginga_ctx_fs_');
      try {
        File('${tempDir.path}/a.txt').writeAsStringSync('alpha');
        File('${tempDir.path}/b.txt').writeAsStringSync('beta');
        final ctx = GingaAppContext(
          appContextId: 'disk_ctx',
          baseUri: tempDir.uri,
        );

        expect(ctx.existsSync('a.txt'), isTrue);
        expect(ctx.listEntriesSync(), ['a.txt', 'b.txt']);
        expect(ctx.removeEntrySync('a.txt'), isTrue);
        expect(ctx.existsSync('a.txt'), isFalse);
        expect(ctx.listEntriesSync(), ['b.txt']);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
