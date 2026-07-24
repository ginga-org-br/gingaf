import 'package:ncldoc/elements.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:ncldoc/parser.dart';
import 'package:test/test.dart';

void main() {
  group('Elements Typed Accessors', () {
    test('NCLParser.parseDurStr parses seconds, milliseconds, and numeric values', () {
      expect(NCLParser.parseDurStr('2.5s'), equals(2500));
      expect(NCLParser.parseDurStr('500ms'), equals(500));
      expect(NCLParser.parseDurStr('3'), equals(3000));
      expect(NCLParser.parseDurStr(null), isNull);
    });

    test('Region attributes are exposed via getters', () {
      final reg = Region(rawAttributes: {
        'id': 'regMain',
        'title': 'Main Region',
        'left': '10%',
        'top': '20%',
        'width': '80%',
        'height': '60%',
        'zIndex': '5',
      });

      expect(reg.id, equals('regMain'));
      expect(reg.title, equals('Main Region'));
      expect(reg.left, equals('10%'));
      expect(reg.top, equals('20%'));
      expect(reg.width, equals('80%'));
      expect(reg.height, equals('60%'));
      expect(reg.zIndex, equals('5'));
    });

    test('Descriptor attributes and explicitDurMs are exposed via getters', () {
      final desc = Descriptor(rawAttributes: {
        'id': 'd1',
        'region': 'regMain',
        'transIn': 'tFade',
        'transOut': 'tWipe',
        'explicitDur': '4s',
        'focusIndex': '1',
      });

      expect(desc.id, equals('d1'));
      expect(desc.region, equals('regMain'));
      expect(desc.transIn, equals('tFade'));
      expect(desc.transOut, equals('tWipe'));
      expect(desc.explicitDur, equals('4s'));
      expect(desc.explicitDurMs, equals(4000));
      expect(desc.focusIndex, equals('1'));
    });

    test('Transition attributes and durMs are exposed via getters', () {
      final trans = Transition(rawAttributes: {
        'id': 'tFade',
        'type': 'fade',
        'subtype': 'crossfade',
        'dur': '1500ms',
        'direction': 'forward',
      });

      expect(trans.id, equals('tFade'));
      expect(trans.type, equals('fade'));
      expect(trans.subtype, equals('crossfade'));
      expect(trans.dur, equals('1500ms'));
      expect(trans.durMs, equals(1500));
      expect(trans.direction, equals('forward'));
    });

    test('Rule attributes are exposed via getters', () {
      final rule = Rule(rawAttributes: {
        'id': 'rLang',
        'var': 'system.language',
        'comparator': 'eq',
        'value': 'pt',
      });

      expect(rule.id, equals('rLang'));
      expect(rule.varName, equals('system.language'));
      expect(rule.comparator, equals('eq'));
      expect(rule.value, equals('pt'));
    });

    test('Link xconnector and binds getters', () {
      final link = Link(rawAttributes: {'id': 'l1', 'xconnector': 'onBeginStart'});
      final bind = Bind(rawAttributes: {'role': 'onBegin', 'component': 'm1'});
      link.children.add(bind);

      expect(link.xconnector, equals('onBeginStart'));
      expect(link.binds.length, equals(1));
      expect(link.binds.first.role, equals('onBegin'));
      expect(link.binds.first.component, equals('m1'));
    });

    test('NCLDocument parses Transition and Rule elements as typed instances', () {
      final doc = NCLDocument.fromXML('''<ncl id="testDoc" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <ruleBase>
      <rule id="r1" var="system.language" comparator="eq" value="en"/>
    </ruleBase>
    <transitionBase>
      <transition id="t1" type="fade" dur="2s"/>
    </transitionBase>
  </head>
  <body/>
</ncl>''');

      final ruleBase = doc.headChildren.firstWhere((e) => e.xmlTagName == 'ruleBase');
      final rule = ruleBase.children.firstWhere((e) => e.id == 'r1');
      expect(rule, isA<Rule>());
      expect((rule as Rule).varName, equals('system.language'));

      final transBase = doc.headChildren.firstWhere((e) => e.xmlTagName == 'transitionBase');
      final trans = transBase.children.firstWhere((e) => e.id == 't1');
      expect(trans, isA<Transition>());
      expect((trans as Transition).durMs, equals(2000));
    });

    test('NCLParser parses assessmentStatement and condition elements correctly', () {
      final xmlString = '''<ncl id="myNCL">
<head>
  <connectorBase>
    <causalConnector id="c1">
      <compoundCondition operator="and">
        <simpleCondition role="onSelection" eventType="selection" key="BLUE"/>
        <assessmentStatement comparator="eq">
          <attributeAssessment role="testAttr" eventType="attribution" key="var" attributeType="nodeProperty"/>
          <valueAssessment value="5"/>
        </assessmentStatement>
      </compoundCondition>
    </causalConnector>
  </connectorBase>
</head>
<body id="body"/>
</ncl>''';

      final doc = NCLDocument.fromXML(xmlString);
      final head = doc.head;
      expect(head, isNotNull);

      final connectorBase = head!.firstWhere((e) => e.xmlTagName == 'connectorBase');
      final connector = connectorBase.children.whereType<Connector>().first;
      expect(connector.id, equals('c1'));

      final compoundCond = connector.children.whereType<CompoundCondition>().first;
      expect(compoundCond.operator, equals('and'));
      expect(compoundCond.conditions.length, equals(2));

      final simpleCond = compoundCond.conditions.whereType<SimpleCondition>().first;
      expect(simpleCond.role, equals('onSelection'));
      expect(simpleCond.eventType, equals('selection'));
      expect(simpleCond.key, equals('BLUE'));

      final assessmentStmt = compoundCond.conditions.whereType<AssessmentStatement>().first;
      expect(assessmentStmt.comparator, equals('eq'));
      expect(assessmentStmt.attributeAssessments.length, equals(1));
      expect(assessmentStmt.valueAssessments.length, equals(1));

      final attrAss = assessmentStmt.attributeAssessments.first;
      expect(attrAss.role, equals('testAttr'));
      expect(attrAss.eventType, equals('attribution'));
      expect(attrAss.key, equals('var'));
      expect(attrAss.attributeType, equals('nodeProperty'));

      final valAss = assessmentStmt.valueAssessments.first;
      expect(valAss.value, equals('5'));
    });

    test('NCLParser parses focus, navigation, and descriptorParam attributes', () {
      final xmlString = '''<ncl id="myNCL">
<head>
  <descriptorBase>
    <descriptor id="dFocus" region="rg1" focusIndex="1" moveUp="dUp" moveDown="dDown" moveLeft="dLeft" moveRight="dRight" focusBorderColor="red" focusBorderWidth="2" focusBorderTransparency="0.5" focusSrc="focus.png" focusSelSrc="sel.png" selectIndex="10">
      <descriptorParam name="fontSize" value="16"/>
      <descriptorParam name="fontColor" value="yellow"/>
    </descriptor>
  </descriptorBase>
</head>
<body id="body"/>
</ncl>''';

      final doc = NCLDocument.fromXML(xmlString);
      final head = doc.head;
      expect(head, isNotNull);

      final descriptorBase = head!.firstWhere((e) => e.xmlTagName == 'descriptorBase');
      final desc = descriptorBase.children.whereType<Descriptor>().first;

      expect(desc.id, equals('dFocus'));
      expect(desc.region, equals('rg1'));
      expect(desc.focusIndex, equals('1'));
      expect(desc.moveUp, equals('dUp'));
      expect(desc.moveDown, equals('dDown'));
      expect(desc.moveLeft, equals('dLeft'));
      expect(desc.moveRight, equals('dRight'));
      expect(desc.focusBorderColor, equals('red'));
      expect(desc.focusBorderWidth, equals('2'));
      expect(desc.focusBorderTransparency, equals('0.5'));
      expect(desc.focusSrc, equals('focus.png'));
      expect(desc.focusSelSrc, equals('sel.png'));
      expect(desc.selectIndex, equals('10'));

      expect(desc.descriptorParams.length, equals(2));
      expect(desc.descriptorParams[0].name, equals('fontSize'));
      expect(desc.descriptorParams[0].value, equals('16'));
      expect(desc.descriptorParams[1].name, equals('fontColor'));
      expect(desc.descriptorParams[1].value, equals('yellow'));
    });

    test('NCLParser parses userBase and userProfile elements correctly', () {
      final xmlString = '''<ncl id="userTestNCL">
<head>
  <userBase id="ub1">
    <userProfile id="up1" name="Alice" age="30" gender="female"/>
  </userBase>
</head>
<body id="body"/>
</ncl>''';

      final doc = NCLDocument.fromXML(xmlString);
      final head = doc.head;
      expect(head, isNotNull);

      final userBase = head!.firstWhere((e) => e.xmlTagName == 'userBase');
      expect(userBase, isA<UserBase>());

      final ub = userBase as UserBase;
      expect(ub.id, equals('ub1'));
      expect(ub.userProfiles.length, equals(1));

      final up = ub.userProfiles.first;
      expect(up.id, equals('up1'));
      expect(up.name, equals('Alice'));
      expect(up.age, equals('30'));
      expect(up.gender, equals('female'));
    });
  });
}
