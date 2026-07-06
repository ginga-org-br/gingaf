import 'package:ncl_doc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('joao07transition', () {
test('NCLDocument parses transitions and transition descriptors correctly', () {
    final doc = NCLDocument.fromXML('''<ncl id="nclTransition" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <transitionBase>
      <transition id="trans1" type="fade" dur="2s"/>
      <transition id="trans2" type="barWipe" dur="1s"/>
    </transitionBase>
    <descriptorBase>
      <descriptor id="dribleDesc" region="frameReg" transIn="trans1" transOut="trans2"/>
    </descriptorBase>
  </head>
  <body/>
</ncl>''');

    final headChildren = doc.headChildren;
    final transBase = headChildren.firstWhere((e) => e.xmlTagName == 'transitionBase');
    expect(transBase.children.length, 2);

    final trans1 = transBase.children.firstWhere((e) => e.rawAttributes['id'] == 'trans1');
    expect(trans1.rawAttributes['type'], 'fade');
    expect(trans1.rawAttributes['dur'], '2s');

    final descBase = headChildren.firstWhere((e) => e.xmlTagName == 'descriptorBase');
    final dribleDesc = descBase.children.firstWhere((e) => e.rawAttributes['id'] == 'dribleDesc');
    expect(dribleDesc.rawAttributes['transIn'], 'trans1');
    expect(dribleDesc.rawAttributes['transOut'], 'trans2');
  });

  

  });
}
