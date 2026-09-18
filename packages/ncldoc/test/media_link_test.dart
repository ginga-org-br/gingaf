import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclDocument Media Only With Links Tests', () {
    test('link onEnd starts another media', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="v1.mp4" type="video/mp4"/>
    <media id="m2" src="v2.mp4" type="video/mp4"/>
    <link id="l1">
      <bind role="onEnd" component="m1"/>
      <bind role="start" component="m2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      final changed1 = doc.tick(1);
      expect(changed1, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('link onBegin starts another media', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="v1.mp4" type="video/mp4"/>
    <media id="m2" src="v2.mp4" type="video/mp4"/>
    <link id="l1">
      <bind role="onBegin" component="m1"/>
      <bind role="start" component="m2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.occurring);
      final changed2 = doc.tick(1);
      expect(changed2, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test(
      'onBeginTestVarStart triggers male ad when system settings gender property is male',
      () {
        final xmlString = '''
<ncl id="sysSettingsDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginTestVarStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="var" attributeType="nodeProperty" eventType="attribution"/>
            <valueAssessment value="\$value"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <media id="sysSettings" type="application/x-ncl-settings">
      <property name="gender" value="male"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <media id="mVideo" src="video.mp4">
      <area id="aSec2" begin="2s"/>
    </media>
    <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
    <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="sysSettings" interface="gender"/>
      <bindParam name="value" value="male"/>
      <bind role="start" component="mMaleAd"/>
    </link>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="sysSettings" interface="gender"/>
      <bindParam name="value" value="female"/>
      <bind role="start" component="mGeneralAd"/>
    </link>
  </body>
</ncl>
''';

        final doc = NclDocument.fromContent(xmlString);

        doc.start();
        expect(doc.isPlaying, isTrue);

        final mMaleAd = doc.getNodeById('mMaleAd') as Media;
        final mGeneralAd = doc.getNodeById('mGeneralAd') as Media;

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mGeneralAd.getMainState(), equals(NclStateType.sleeping));

        doc.tick(2000);

        expect(mMaleAd.getMainState(), equals(NclStateType.occurring));
        expect(mGeneralAd.getMainState(), equals(NclStateType.sleeping));
      },
    );

    test(
      'onBeginTestVarStart triggers general ad when system settings gender property is female',
      () {
        final xmlString = '''
<ncl id="sysSettingsDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginTestVarStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="var" attributeType="nodeProperty" eventType="attribution"/>
            <valueAssessment value="\$value"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <media id="sysSettings" type="application/x-ncl-settings">
      <property name="gender" value="female"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <media id="mVideo" src="video.mp4">
      <area id="aSec2" begin="2s"/>
    </media>
    <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
    <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="sysSettings" interface="gender"/>
      <bindParam name="value" value="male"/>
      <bind role="start" component="mMaleAd"/>
    </link>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="sysSettings" interface="gender"/>
      <bindParam name="value" value="female"/>
      <bind role="start" component="mGeneralAd"/>
    </link>
  </body>
</ncl>
''';

        final doc = NclDocument.fromContent(xmlString);

        doc.start();
        expect(doc.isPlaying, isTrue);

        final mMaleAd = doc.getNodeById('mMaleAd') as Media;
        final mGeneralAd = doc.getNodeById('mGeneralAd') as Media;

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mGeneralAd.getMainState(), equals(NclStateType.sleeping));

        doc.tick(2000);

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mGeneralAd.getMainState(), equals(NclStateType.occurring));
      },
    );
  });
}
