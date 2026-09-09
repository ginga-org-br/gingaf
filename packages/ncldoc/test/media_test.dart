import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclDocument Media Only Tests', () {
    test('NclDocument initializes and starts ticking', () async {
      const xml = r'''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="media.mp4"/>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      doc.stop();
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('state of media elements doc', () {
      const xmlString = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <ncl>
          <body>
            <media id="video1" src="video.mp4" descriptor="desc1" />
            <media id="audio1" src="audio.mp3" descriptor="desc2" />
          </body>
        </ncl>
        ''';
      final doc = NclDocument.fromContent(xmlString);
      doc.start();
      final changed0 = doc.tick(10);
      expect(changed0, isEmpty);
      expect(doc.getNodeById('video1')?.getMainState(), NclStateType.sleeping);
      doc.stop();
      expect(doc.getNodeById('video1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getNodeById('audio1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('state of image.ncl', () {
      const String imageNcl = r'''
        <ncl>
          <body>
            <port id="init" component="ginga_logo"/>
            <media id="ginga_logo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png" />
          </body>
        </ncl>
        ''';
      final doc = NclDocument.fromContent(imageNcl);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.getNodeById('ginga_logo')?.getMainState(), NclStateType.occurring);
      doc.stop();
      expect(doc.getNodeById('ginga_logo')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('state of media with properties doc', () {
      const xmlString = '''
        <ncl>
          <body>
            <media id="lua_script" src="main.lua">
              <property name="fontColor" value="blue" />
            </media>
          </body>
        </ncl>
        ''';
      final doc = NclDocument.fromContent(xmlString);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.getNodeById('lua_script')?.getMainState(), NclStateType.sleeping);
      doc.stop();
      expect(doc.getNodeById('lua_script')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('start media with property from port', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="v1.mp4" type="video/mp4">
      <property name="visible" value="true"/>
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      expect(doc.getBodyState(), NclStateType.occurring);
      final changed1 = doc.tick(1);
      expect(changed1, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('start single media from port', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="v1.mp4" type="video/mp4"/>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      final changed2 = doc.tick(1);
      expect(changed2, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('start NCLua media', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="script.lua"/>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      final changed3 = doc.tick(1);
      expect(changed3, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('state of media with areas doc', () {
      const xmlString = '''
<ncl>
  <body>
    <media id="video_main" src="main.mp4">
      <area id="seg1" begin="10s" end="20s" />
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xmlString);
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.getNodeById('video_main')?.getMainState(), NclStateType.sleeping);
      doc.stop();
      expect(doc.getNodeById('video_main')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('start media with area from port', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="video_main"/>
    <media id="video_main" src="main.mp4">
      <area id="seg1" begin="10s" end="20s" />
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('video_main')?.getMainState(), NclStateType.occurring);
      expect(doc.getBodyState(), NclStateType.occurring);
      final changed4 = doc.tick(1);
      expect(changed4, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('video_main')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('area timing triggers begin and end events', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="video_main"/>
    <media id="video_main" src="main.mp4">
      <area id="seg1" begin="10s" end="20s" />
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      final video = doc.getNodeById('video_main')!;
      final areaNclEvent = video.getAreaNclEvent('seg1');
      expect(video.getMainState(), NclStateType.occurring);
      expect(areaNclEvent.state, NclStateType.sleeping);

      final changed5a = doc.tick(5000);
      expect(changed5a, isEmpty);
      expect(areaNclEvent.state, NclStateType.sleeping);

      final changed5b = doc.tick(5000);
      expect(changed5b, isNotEmpty);
      expect(areaNclEvent.state, NclStateType.occurring);

      final changed5c = doc.tick(9000);
      expect(changed5c, isEmpty);
      expect(areaNclEvent.state, NclStateType.occurring);

      final changed5d = doc.tick(1000);
      expect(changed5d, isNotEmpty);
      expect(areaNclEvent.state, NclStateType.sleeping);
    });

    test('area begin triggers causal link to start another media', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="video_main"/>
    <media id="video_main" src="main.mp4">
      <area id="seg1" begin="5s" />
    </media>
    <media id="m2" src="image.png"/>
    <link id="l1">
      <bind role="onBegin" component="video_main" interface="seg1"/>
      <bind role="start" component="m2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getNodeById('video_main')?.getMainState(), NclStateType.occurring);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.sleeping);

      final changed6a = doc.tick(4000);
      expect(changed6a, isEmpty);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.sleeping);

      final changed6b = doc.tick(1000);
      expect(changed6b, isNotEmpty);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.occurring);
    });

    test('area end triggers causal link to stop another media', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="video_main"/>
    <port id="p2" component="m2"/>
    <media id="video_main" src="main.mp4">
      <area id="seg1" begin="5s" end="10s" />
    </media>
    <media id="m2" src="image.png"/>
    <link id="l1">
      <bind role="onEnd" component="video_main" interface="seg1"/>
      <bind role="stop" component="m2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();
      expect(doc.getNodeById('video_main')?.getMainState(), NclStateType.occurring);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.occurring);

      final changed7a = doc.tick(9000);
      expect(changed7a, isNotEmpty);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.occurring);

      final changed7b = doc.tick(1000);
      expect(changed7b, isNotEmpty);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.sleeping);
    });

    test(
      'AV media nodes are tracked as timed nodes and stop on expected duration',
      () {
        const xml = '''
<ncl>
  <body>
    <port id="p1" component="video1"/>
    <media id="video1" src="v1.mp4" expectedDuration="5s"/>
  </body>
</ncl>
''';
        final doc = NclDocument.fromContent(xml);
        doc.start();
        final video = doc.getNodeById('video1') as AVMedia;
        expect(video.getMainState(), NclStateType.occurring);
        expect(video, isA<AVMedia>());

        expect(video.time, 0);

        final changedA = doc.tick(4000);
        expect(changedA, isEmpty);
        expect(video.time, 4000);
        expect(video.getMainState(), NclStateType.occurring);

        final changedB = doc.tick(1000);
        expect(changedB, isNotEmpty);
        expect(video.time, 5000);
        expect(video.getMainState(), NclStateType.sleeping);
      },
    );
  });
}
