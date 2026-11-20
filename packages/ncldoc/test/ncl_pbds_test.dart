import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclPBDS', () {
    test('manages lifecycle, auxiliary bases, and NclDocument instances', () {
      final pbds = NclPBDS(
        id: 'pb_main',
        baseUri: Uri.parse('file:///app/main.ncl'),
        state: NclPBDS.stateOpen,
      );

      expect(pbds.id, 'pb_main');
      expect(pbds.getBase(), same(pbds));
      expect(pbds.state, NclPBDS.stateOpen);
      expect(pbds.isPersistent, isFalse);

      pbds.activate();
      pbds.save();
      expect(pbds.state, NclPBDS.stateActive);
      expect(pbds.isPersistent, isTrue);

      final doc = pbds.addDocument(
        'doc1',
        uri: 'main.ncl',
        content: '<ncl id="doc1"><body/></ncl>',
      );
      expect(doc, isA<NclDocument>());
      expect(NclPBDS.documentState(doc), 'sleeping');
      expect(pbds.getDocument('doc1')?.docSrc, 'main.ncl');

      doc.start();
      expect(NclPBDS.documentState(doc), 'occurring');

      doc.pause();
      expect(NclPBDS.documentState(doc), 'paused');

      doc.resume();
      expect(NclPBDS.documentState(doc), 'occurring');

      doc.stop();
      expect(NclPBDS.documentState(doc), 'sleeping');

      final auxBase = pbds.openBase(baseId: 'aux_base');
      expect(auxBase, isA<NclPBDS>());
      expect(pbds.baseIds, containsAll(['pb_main', 'aux_base']));
      expect(pbds.closeBase('aux_base'), isTrue);
      expect(pbds.getBase('aux_base'), isNull);

      final meta = pbds.toMetadataMap();
      expect(meta['baseId'], 'pb_main');
      expect(meta['state'], 'active');
      expect(meta['persistent'], isTrue);
      expect(meta['baseUri'], 'file:///app/main.ncl');
      expect((meta['documents'] as List).length, 1);

      expect(pbds.removeDocument('doc1'), isTrue);
      expect(pbds.getDocument('doc1'), isNull);

      pbds.deactivate();
      expect(pbds.state, NclPBDS.stateOpen);

      pbds.close();
      expect(pbds.state, NclPBDS.stateClosed);
    });

    test('NclDocument registers itself in NclPBDS and reflects live state', () {
      final doc = NclDocument.fromContent(
        '<ncl id="docLifecycle"><body><port id="p1" component="m1"/><media id="m1" type="text/plain"/></body></ncl>',
        applicationId: 'docLifecycle',
      );

      expect(doc.pbds, isA<NclPBDS>());
      expect(doc.pbds.id, 'docLifecycle');
      expect(doc.pbds.getDocument('docLifecycle'), same(doc));
      expect(NclPBDS.documentState(doc), 'sleeping');

      doc.start();
      expect(NclPBDS.documentState(doc), 'occurring');

      doc.pause();
      expect(NclPBDS.documentState(doc), 'paused');

      doc.resume();
      expect(NclPBDS.documentState(doc), 'occurring');

      doc.stop();
      expect(NclPBDS.documentState(doc), 'sleeping');
    });
  });
}

