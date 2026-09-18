import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclScheduler Variable Resolution Tests', () {
    test(r'resolves $qualquerNome from matching bind role', () {
      const xml = '''
<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="\$var"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="srcMedia" type="text/plain">
      <property name="srcProp" value="hello"/>
    </media>
    <media id="m1" type="video/mp4"/>
    <media id="dstMedia" type="text/plain">
      <property name="dstProp" value="initial"/>
    </media>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="m1"/>
      <bind role="getValue" component="srcMedia" interface="srcProp"/>
      <bind role="set" component="dstMedia" interface="dstProp">
        <bindParam name="var" value="\$getValue"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getPropertyValue(doc.getNodeById('dstMedia')!, 'dstProp'), 'hello');
    });

    test('resolves multiple gets and sets in a single link', () {
      const xml = '''
<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="\$var" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="uSettings" type="application/x-ncl-settings">
      <property name="id" value="u1"/>
      <property name="name" value="Alice"/>
      <property name="gender" value="female"/>
      <property name="age" value="25"/>
    </media>
    <media id="m1" type="video/mp4"/>
    <media id="mUserLua" type="text/plain">
      <property name="userId" value=""/>
      <property name="userName" value=""/>
      <property name="userGender" value=""/>
      <property name="userAge" value=""/>
    </media>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="m1"/>
      <bind role="get" component="uSettings" interface="id"/>
      <bind role="get" component="uSettings" interface="name"/>
      <bind role="get" component="uSettings" interface="gender"/>
      <bind role="get" component="uSettings" interface="age"/>
      <bind role="set" component="mUserLua" interface="userId">
        <bindParam name="var" value="\$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userName">
        <bindParam name="var" value="\$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userGender">
        <bindParam name="var" value="\$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userAge">
        <bindParam name="var" value="\$get"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      final luaNode = doc.getNodeById('mUserLua')!;
      expect(doc.getPropertyValue(luaNode, 'userId'), 'u1');
      expect(doc.getPropertyValue(luaNode, 'userName'), 'Alice');
      expect(doc.getPropertyValue(luaNode, 'userGender'), 'female');
      expect(doc.getPropertyValue(luaNode, 'userAge'), '25');
    });

    test('resolves distinct role names per property', () {
      const xml = '''
<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="\$var" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="srcNode" type="text/plain">
      <property name="alpha" value="100"/>
      <property name="beta" value="200"/>
    </media>
    <media id="m1" type="video/mp4"/>
    <media id="dstNode" type="text/plain">
      <property name="propA" value="0"/>
      <property name="propB" value="0"/>
    </media>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="m1"/>
      <bind role="getAlpha" component="srcNode" interface="alpha"/>
      <bind role="getBeta" component="srcNode" interface="beta"/>
      <bind role="set" component="dstNode" interface="propA">
        <bindParam name="var" value="\$getAlpha"/>
      </bind>
      <bind role="set" component="dstNode" interface="propB">
        <bindParam name="var" value="\$getBeta"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      final dst = doc.getNodeById('dstNode')!;
      expect(doc.getPropertyValue(dst, 'propA'), '100');
      expect(doc.getPropertyValue(dst, 'propB'), '200');
    });

    test('does not perform attribution if variable value cannot be obtained', () {
      const xml = '''
<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="\$var"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" type="video/mp4"/>
    <media id="dstNode" type="text/plain">
      <property name="targetProp" value="unchanged"/>
    </media>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="m1"/>
      <bind role="set" component="dstNode" interface="targetProp">
        <bindParam name="var" value="\$missingRole"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      final dst = doc.getNodeById('dstNode')!;
      expect(doc.getPropertyValue(dst, 'targetProp'), 'unchanged');
    });

    test('resolves variable in onSelection trigger', () {
      const xml = '''
<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onSelectSet">
        <connectorParam name="var"/>
        <simpleCondition role="onSelection"/>
        <simpleAction role="set" value="\$var"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="mBtn"/>
    <media id="mBtn" type="image/png"/>
    <media id="source" type="text/plain">
      <property name="val" value="active"/>
    </media>
    <media id="target" type="text/plain">
      <property name="status" value="idle"/>
    </media>
    <link xconnector="onSelectSet">
      <bind role="onSelection" component="mBtn"/>
      <bind role="getValue" component="source" interface="val"/>
      <bind role="set" component="target" interface="status">
        <bindParam name="var" value="\$getValue"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      final targetNode = doc.getNodeById('target')!;
      expect(doc.getPropertyValue(targetNode, 'status'), 'idle');
      doc.triggerSelection('mBtn', 'ENTER');
      doc.tick(0);
      expect(doc.getPropertyValue(targetNode, 'status'), 'active');
    });
  });
}
