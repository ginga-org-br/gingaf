import 'package:ncl_doc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('primeiro_joao_08animation', () {
    test(
      'NCLDocument executes duration-based SET action property changes correctly',
      () {
        final doc = NCLDocument.fromXML(
          '''<ncl id="nclAnimation" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <connectorBase>
      <causalConnector id="onBeginStartSet_var_delay_duration">
        <connectorParam name="var"/>
        <connectorParam name="delay"/>
        <connectorParam name="duration"/>
        <simpleCondition role="onBegin"/>
        <compoundAction operator="seq">
          <simpleAction role="start"/>
          <simpleAction role="set" value="\$var" delay="\$delay" duration="\$duration"/>
        </compoundAction>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="m1.mp4">
      <area id="a1" begin="10s"/>
    </media>
    <media id="m2" src="m2.png">
      <property name="p"/>
    </media>
    <link id="l1" xconnector="onBeginStartSet_var_delay_duration">
      <bind role="onBegin" component="m1" interface="a1"/>
      <bind role="start" component="m2"/>
      <bind role="set" component="m2" interface="p">
        <bindParam name="var" value="active"/>
        <bindParam name="delay" value="2s"/>
        <bindParam name="duration" value="5s"/>
      </bind>
    </link>
  </body>
</ncl>''',
        );

        doc.start();
        doc.tick(10000);

        final m2 = doc.getNodeById('m2') as Media;
        final prop = m2.getPropertyEvent('p');

        expect(m2.getMainState(), State.OCCURRING);
        expect(prop.state, State.SLEEPING);

        doc.tick(1000);
        expect(prop.state, State.SLEEPING);

        doc.tick(1000);
        expect(prop.state, State.OCCURRING);
        expect(
          m2.getProperties().firstWhere((p) => p.name == 'p').value,
          isNull,
        );

        doc.tick(4000);
        expect(prop.state, State.OCCURRING);

        doc.tick(1000);
        expect(prop.state, State.SLEEPING);
        final pVal = m2.getProperties().firstWhere((p) => p.name == 'p');
        expect(pVal.value, 'active');
      },
    );
  });
}
