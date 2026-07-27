import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCL Editing Commands Head Tests', () {

test('routes and executes addRegion and removeRegion', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <regionBase id="base1">
            <region id="reg1" />
          </regionBase>
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.getElementById('reg2'), isNull);

      doc.doNclEditingCommand('addRegion("base1", "reg1", "<region id=\\"reg2\\" />")');
      expect(doc.getElementById('reg2'), isNotNull);

      doc.doNclEditingCommand('removeRegion("reg2")');
      expect(doc.getElementById('reg2'), isNull);
    });

test('routes and executes addRegionBase and removeRegionBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head />
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.headChildren.where((e) => e.xmlTagName == 'regionBase').isEmpty, isTrue);

      doc.doNclEditingCommand('addRegionBase("<regionBase id=\\"base1\\" />")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'regionBase').isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeRegionBase("base1")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'regionBase').isEmpty, isTrue);
    });

test('routes and executes addRuleBase and removeRuleBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head />
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.headChildren.where((e) => e.xmlTagName == 'ruleBase').isEmpty, isTrue);

      doc.doNclEditingCommand('addRuleBase("<ruleBase id=\\"base1\\" />")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'ruleBase').isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeRuleBase("base1")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'ruleBase').isEmpty, isTrue);
    });

test('routes and executes addRule and removeRule', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <ruleBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final ruleBase = doc.headChildren.where((e) => e.xmlTagName == 'ruleBase').first;
      expect(ruleBase.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addRule("<rule id=\\"rule1\\" var=\\"system.language\\" value=\\"en\\" comparator=\\"eq\\" />")');
      expect(ruleBase.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeRule("rule1")');
      expect(ruleBase.children.isEmpty, isTrue);
    });

test('routes and executes addConnectorBase and removeConnectorBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head />
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.headChildren.where((e) => e.xmlTagName == 'connectorBase').isEmpty, isTrue);

      doc.doNclEditingCommand('addConnectorBase("<connectorBase id=\\"base1\\" />")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'connectorBase').isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeConnectorBase("base1")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'connectorBase').isEmpty, isTrue);
    });

test('routes and executes addConnector and removeConnector', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <connectorBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final connBase = doc.headChildren.where((e) => e.xmlTagName == 'connectorBase').first;
      expect(connBase.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addConnector("<causalConnector id=\\"conn1\\" />")');
      expect(connBase.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeConnector("conn1")');
      expect(connBase.children.isEmpty, isTrue);
    });

test('routes and executes addDescriptorBase and removeDescriptorBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head />
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.headChildren.where((e) => e.xmlTagName == 'descriptorBase').isEmpty, isTrue);

      doc.doNclEditingCommand('addDescriptorBase("<descriptorBase id=\\"base1\\" />")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'descriptorBase').isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeDescriptorBase("base1")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'descriptorBase').isEmpty, isTrue);
    });

test('routes and executes addDescriptor and removeDescriptor', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <descriptorBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.getElementById('desc1'), isNull);

      doc.doNclEditingCommand('addDescriptor("<descriptor id=\\"desc1\\" />")');
      expect(doc.getElementById('desc1'), isNotNull);

      doc.doNclEditingCommand('removeDescriptor("desc1")');
      expect(doc.getElementById('desc1'), isNull);
    });

test('routes and executes addDescriptorSwitch and removeDescriptorSwitch', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <descriptorBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final descBase = doc.headChildren.where((e) => e.xmlTagName == 'descriptorBase').first;
      expect(descBase.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addDescriptorSwitch("<descriptorSwitch id=\\"dsw1\\" />")');
      expect(descBase.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeDescriptorSwitch("dsw1")');
      expect(descBase.children.isEmpty, isTrue);
    });

test('routes and executes addTransitionBase and removeTransitionBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head />
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.headChildren.where((e) => e.xmlTagName == 'transitionBase').isEmpty, isTrue);

      doc.doNclEditingCommand('addTransitionBase("<transitionBase id=\\"base1\\" />")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'transitionBase').isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeTransitionBase("base1")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'transitionBase').isEmpty, isTrue);
    });

test('routes and executes addTransition and removeTransition', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <transitionBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final transBase = doc.headChildren.where((e) => e.xmlTagName == 'transitionBase').first;
      expect(transBase.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addTransition("<transition id=\\"trans1\\" type=\\"fade\\" />")');
      expect(transBase.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeTransition("trans1")');
      expect(transBase.children.isEmpty, isTrue);
    });

test('routes and executes addImportedDocumentBase and removeImportedDocumentBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head />
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.headChildren.where((e) => e.xmlTagName == 'importedDocumentBase').isEmpty, isTrue);

      doc.doNclEditingCommand('addImportedDocumentBase("<importedDocumentBase id=\\"base1\\" />")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'importedDocumentBase').isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeImportedDocumentBase("base1")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'importedDocumentBase').isEmpty, isTrue);
    });

test('routes and executes addImportBase and removeImportBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <importedDocumentBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final impBase = doc.headChildren.where((e) => e.xmlTagName == 'importedDocumentBase').first;
      expect(impBase.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addImportBase("<importBase documentURI=\\"doc1.ncl\\" alias=\\"alias1\\" />")');
      expect(impBase.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeImportBase("doc1.ncl")');
      expect(impBase.children.isEmpty, isTrue);
    });

test('routes and executes addImportNCL and removeImportNCL', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <importedDocumentBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final impBase = doc.headChildren.where((e) => e.xmlTagName == 'importedDocumentBase').first;
      expect(impBase.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addImportNCL("<importNCL documentURI=\\"doc1.ncl\\" alias=\\"alias1\\" />")');
      expect(impBase.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeImportNCL("doc1.ncl")');
      expect(impBase.children.isEmpty, isTrue);
    });

test('routes and executes addFontBase and removeFontBase', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head />
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.headChildren.where((e) => e.xmlTagName == 'fontBase').isEmpty, isTrue);

      doc.doNclEditingCommand('addFontBase("<fontBase id=\\"base1\\" />")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'fontBase').isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeFontBase("base1")');
      expect(doc.headChildren.where((e) => e.xmlTagName == 'fontBase').isEmpty, isTrue);
    });

test('routes and executes addFont and removeFont', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <head>
          <fontBase id="base1" />
        </head>
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final fontBase = doc.headChildren.where((e) => e.xmlTagName == 'fontBase').first;
      expect(fontBase.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addFont("<font family=\\"Arial\\" style=\\"normal\\" weight=\\"bold\\" />")');
      expect(fontBase.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeFont("Arial", "normal", "bold")');
      expect(fontBase.children.isEmpty, isTrue);
    });
  });
}
