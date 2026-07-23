import 'package:test/test.dart';
import 'package:ncl_doc/ncl_document.dart';

void main() {
  group('NCLua Tests', () {
    late NCLua engine;
    setUp(() {
      engine = NCLua();
    });

    test('Lua script canvas constructors', () {
      final script = '''
        local c1 = canvas.new()
        local c2 = canvas.new("my_image.png")
        local c3 = canvas.new(800, 600)
        local c4 = canvas.new(12345)
      ''';
      engine.execute(script);
      expect(engine.canvasCalls.length, 4);
      expect(engine.canvasCalls[0].method, 'new_empty');
      expect(engine.canvasCalls[1].method, 'new_image');
      expect(engine.canvasCalls[1].args, ['my_image.png']);
      expect(engine.canvasCalls[2].method, 'new_size');
      expect(engine.canvasCalls[2].args, [800.0, 600.0]);
      expect(engine.canvasCalls[3].method, 'new_buff');
      expect(engine.canvasCalls[3].args, ['12345']);
    });

    test('Lua script canvas attributes functions', () {
      final script = '''
        local c = canvas.new()
        c:attrSize(100, 200)
        local w, h = c:attrSize()
        c:attrColor(10, 20, 30, 40)
        local cr, cg, cb, ca = c:attrColor()
        c:attrFont("Arial", 16, "italic", "bold")
        local ff, fs, fst, fw = c:attrFont()
        c:attrClip(5, 6, 7, 8)
        local clx, cly, clw, clh = c:attrClip()
        c:attrCrop(1, 2, 3, 4)
        local crx, cry, crw, crh = c:attrCrop()
        c:attrFlip(true, false)
        local fh, fv = c:attrFlip()
        c:attrOpacity(127)
        local op = c:attrOpacity()
        c:attrRotation(45)
        local rot = c:attrRotation()
        c:attrScale(2.5, 3.5)
        local sx, sy = c:attrScale()
      ''';
      engine.execute(script);
      expect(engine.canvasCalls.any((call) => call.method == 'attrSize'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrColor'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrFont'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrClip'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrCrop'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrFlip'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrOpacity'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrRotation'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrScale'), true);
    });

    test('Lua script canvas attributes property mapping', () {
      final script = '''
        local c = canvas.new()
        c.size = {300, 400}
        c.color = {50, 60, 70, 80}
        c.opacity = 200
        c.rotation = 90
        
        local sz = c.size
        local col = c.color
        local op = c.opacity
        local rot = c.rotation
      ''';
      engine.execute(script);
      expect(engine.canvasCalls.any((call) => call.method == 'attrSize'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrColor'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrOpacity'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'attrRotation'), true);
    });

    test('Lua script drawing primitives', () {
      final script = '''
        local c = canvas.new()
        c:drawLine(1, 2, 3, 4)
        c:drawRect("fill", 10, 20, 30, 40)
        c:drawRoundRect("stroke", 15, 25, 35, 45, 5, 5)
        c:drawPolygon({100, 100, 150, 100, 125, 150})
        c:drawEllipse("fill", 50, 50, 80, 80)
        c:drawText("hello", 10, 10)
        c:drawText(10, 10, "hello")
        c:drawTextRect("world", 20, 20, 200, 100, "center", "center")
        c:drawTextRect(20, 20, 200, 100, "world", "center", "center")
        c:dump("png")
      ''';
      engine.execute(script);
      expect(engine.canvasCalls.any((call) => call.method == 'drawLine'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'drawRect'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'drawRoundRect'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'drawPolygon'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'drawEllipse'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'drawText'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'drawTextRect'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'dump'), true);
    });

    test('Lua script miscellaneous methods', () {
      final script = '''
        local c = canvas.new()
        c:clear()
        c:flush()
        local other = canvas.new("other.png")
        c:compose(other, 10, 20)
        local r, g, b, a = c:pixel(100, 100)
        c:pixel(100, 100, 255, 0, 0, 255)
        local w, h = c:measureText("test")
      ''';
      engine.execute(script);
      expect(engine.canvasCalls.any((call) => call.method == 'clear'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'flush'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'compose'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'getPixel'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'setPixel'), true);
      expect(engine.canvasCalls.any((call) => call.method == 'measureText'), true);
    });

    test('Named colors are correctly mapped in Lua wrapper', () {
      final script = '''
        local c = canvas.new()
        c:attrColor('red')
      ''';
      engine.execute(script);
      expect(engine.canvasCalls.length, 2);
      expect(engine.canvasCalls[1].method, 'attrColor');
      expect(engine.canvasCalls[1].args, [255, 0, 0, 255]);
    });

    test('clearBuffer empties the calls list', () {
      engine.execute('canvas.new():drawRect("fill", 0, 0, 1, 1)');
      expect(engine.canvasCalls.isNotEmpty, true);
      engine.clearBuffer();
      expect(engine.canvasCalls.isEmpty, true);
    });
  });
}
