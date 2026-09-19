import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLua Runtime Tests', () {
    late NclDocument doc;
    late NCLuaRuntime runtime;
    setUp(() {
      doc = NclDocument.fromContent('<ncl><head/><body/></ncl>');
      runtime = NCLuaRuntime(document: doc);
    });


    test('Lua script event registration and posting', () {
      final script = '''
        local event = require 'event'
        local received = nil
        event.register(function(evt)
          received = evt
        end)
        event.post('in', { class = 'user', type = 'custom', value = 'hello' })
        _G.test_received = received
      ''';
      runtime.execute(script);
      runtime.luaState.getGlobal('test_received');
      expect(runtime.luaState.isTable(-1), true);
      runtime.luaState.getField(-1, 'class');
      expect(runtime.luaState.toStr(-1), 'user');
      runtime.luaState.pop(1);
      runtime.luaState.getField(-1, 'value');
      expect(runtime.luaState.toStr(-1), 'hello');
      runtime.luaState.pop(2);
    });

    test('Lua script event unregistration', () {
      final script = '''
        local event = require 'event'
        _G.test_received = nil
        local function handler(evt)
          _G.test_received = evt
        end
        event.register(handler)
        event.unregister(handler)
        event.post('in', { class = 'user', type = 'custom' })
      ''';
      runtime.execute(script);
      runtime.luaState.getGlobal('test_received');
      expect(runtime.luaState.isNil(-1), true);
      runtime.luaState.pop(1);
    });

    test('Lua script event classes validation and support', () {
      final script = '''
        local event = require 'event'
        local last_class = nil
        event.register(function(evt)
          last_class = evt.class
        end)
        local classes = {
          'key', 'pointer', 'ncl', 'edit', 'tcp', 'udp', 'http', 'sms', 'si',
          'sectionfilter', 'pesfilter', 'tpfilter', 'zip', 'streambuf',
          'broadcastfs', 'mediakeysession', 'user'
        }
        _G.received_classes = {}
        for _, cls in ipairs(classes) do
          event.post('in', { class = cls })
          table.insert(_G.received_classes, last_class)
        end
      ''';
      runtime.execute(script);
      runtime.luaState.getGlobal('received_classes');
      expect(runtime.luaState.isTable(-1), true);
      final classes = [
        'key', 'pointer', 'ncl', 'edit', 'tcp', 'udp', 'http', 'sms', 'si',
        'sectionfilter', 'pesfilter', 'tpfilter', 'zip', 'streambuf',
        'broadcastfs', 'mediakeysession', 'user'
      ];
      for (int i = 0; i < classes.length; i++) {
        runtime.luaState.getI(-1, i + 1);
        expect(runtime.luaState.toStr(-1), classes[i]);
        runtime.luaState.pop(1);
      }
      runtime.luaState.pop(1);
    });

    test('Lua script event timer and uptime', () {
      int mockUptime = 100;
      runtime.uptimeProvider = () => mockUptime;
      final script = '''
        local event = require 'event'
        _G.timer_triggered = false
        _G.initial_uptime = event.uptime()
        event.timer(50, function(evt)
          _G.timer_triggered = true
        end)
      ''';
      runtime.execute(script);
      runtime.luaState.getGlobal('initial_uptime');
      expect(runtime.luaState.toInteger(-1), 100);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('timer_triggered');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);

      mockUptime = 160;
      runtime.tickTimers(mockUptime);

      runtime.luaState.getGlobal('timer_triggered');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);
    });

    test('Lua settings table read-only and group access', () {
      doc.dispatchSettingsUpdate('system.language', 'por');
      doc.dispatchSettingsUpdate('user.age', '25');
      final script = '''
        _G.lang = settings.system.language
        _G.age = settings.user.age
        _G.nonexistent = settings.default.some_prop
        
        local ok, err = pcall(function()
          settings.system.language = "en"
        end)
        _G.write_error_1 = ok
        
        local ok2, err2 = pcall(function()
          settings.system = {}
        end)
        _G.write_error_2 = ok2
      ''';
      runtime.execute(script);
      
      runtime.luaState.getGlobal('lang');
      expect(runtime.luaState.toStr(-1), 'por');
      runtime.luaState.pop(1);
      
      runtime.luaState.getGlobal('age');
      expect(runtime.luaState.toStr(-1), '25');
      runtime.luaState.pop(1);
      
      runtime.luaState.getGlobal('nonexistent');
      expect(runtime.luaState.isNil(-1), true);
      runtime.luaState.pop(1);
      
      runtime.luaState.getGlobal('write_error_1');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);
      
      runtime.luaState.getGlobal('write_error_2');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);
    });

    test('Lua persistent table read-write and group access', () {
      final script = '''
        persistent.service.var1 = "hello"
        _G.val1 = persistent.service.var1
        
        persistent.channel.var2 = 42
        _G.val2 = persistent.channel.var2

        persistent.var3 = "direct"
        _G.val3 = persistent.var3
        
        local ok, err = pcall(function()
          persistent.service = {}
        end)
        _G.write_error = ok
      ''';
      runtime.execute(script);
      
      runtime.luaState.getGlobal('val1');
      expect(runtime.luaState.toStr(-1), 'hello');
      runtime.luaState.pop(1);
      
      runtime.luaState.getGlobal('val2');
      expect(runtime.luaState.toStr(-1), '42');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('val3');
      expect(runtime.luaState.toStr(-1), 'direct');
      runtime.luaState.pop(1);
      
      runtime.luaState.getGlobal('write_error');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);

      expect(doc.getSystemVariable('service.var1'), 'hello');
      expect(doc.getSystemVariable('channel.var2'), '42');
      expect(doc.getSystemVariable('persistent.var3'), 'direct');
    });

    test('Lua helper module: dir', () {
      final script = '''
        local dir = require "dir"

        _G.test_dir_list = ""
        for item in dir.list("/some/path") do
            _G.test_dir_list = _G.test_dir_list .. item .. ","
        end

        _G.test_dir_test_dir = dir.test("/some/dir/", "d")
        _G.test_dir_test_nonexistent = dir.test("/nonexistent", "f")
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_dir_list');
      expect(runtime.luaState.toStr(-1), 'file1.txt,file2.png,');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_dir_test_dir');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_dir_test_nonexistent');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);
    });

    test('Lua helper module: pbds', () {
      final script = '''
        local pbds = require "pbds"
        _G.test_pbds_exists = (pbds ~= nil and type(pbds) == "table")
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_pbds_exists');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);
    });

    test('Lua helper module: charset', () {
      final script = '''
        local charset = require "charset"
        _G.test_charset_convert = charset.convert("hello", "utf-8", "iso-8859-1")
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_charset_convert');
      expect(runtime.luaState.toStr(-1), 'hello');
      runtime.luaState.pop(1);
    });

    test('Lua helper module: network', () {
      final script = '''
        local network = require "network"
        local interfaces = network.listInterfaces()
        _G.test_network_name = interfaces[1].name
        _G.test_network_ip = interfaces[1].ip
        _G.test_network_mac = interfaces[1].mac
        _G.test_network_active = interfaces[1].active
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_network_name');
      expect(runtime.luaState.toStr(-1), 'eth0');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_network_ip');
      expect(runtime.luaState.toStr(-1), '192.168.1.100');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_network_mac');
      expect(runtime.luaState.toStr(-1), '00:11:22:33:44:55');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_network_active');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);
    });

    test('Lua helper module: zip', () {
      final script = '''
        local zip = require "zip"
        local z = zip.open("test.zip")
        _G.test_zip_path = z:attrPath()
        _G.test_zip_exists_before = z:exists("main.lua")
        z:append("newfile.txt", "data")
        _G.test_zip_exists_after = z:exists("newfile.txt")
        _G.test_zip_remove_ok = z:remove("main.lua")
        _G.test_zip_exists_after_remove = z:exists("main.lua")
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_zip_path');
      expect(runtime.luaState.toStr(-1), 'test.zip');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_zip_exists_before');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_zip_exists_after');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_zip_remove_ok');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_zip_exists_after_remove');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);
    });

    test('Lua helper module: bit32', () {
      final script = '''
        local bit32 = require "bit32"
        _G.test_bit32_band = bit32.band(6, 3)
        _G.test_bit32_bor = bit32.bor(4, 2)
        _G.test_bit32_bxor = bit32.bxor(5, 3)
        _G.test_bit32_bnot = bit32.bnot(0)
        _G.test_bit32_arshift = bit32.arshift(-8, 1)
        _G.test_bit32_lrotate = bit32.lrotate(1, 4)
        _G.test_bit32_rrotate = bit32.rrotate(16, 4)
        _G.test_bit32_extract = bit32.extract(255, 4, 4)
        _G.test_bit32_replace = bit32.replace(0, 15, 4, 4)
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_bit32_band');
      expect(runtime.luaState.toInteger(-1), 2);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_bor');
      expect(runtime.luaState.toInteger(-1), 6);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_bxor');
      expect(runtime.luaState.toInteger(-1), 6);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_bnot');
      expect(runtime.luaState.toInteger(-1), 0xFFFFFFFF);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_arshift');
      expect(runtime.luaState.toInteger(-1), 0xFFFFFFFC);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_lrotate');
      expect(runtime.luaState.toInteger(-1), 16);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_rrotate');
      expect(runtime.luaState.toInteger(-1), 1);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_extract');
      expect(runtime.luaState.toInteger(-1), 15);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_bit32_replace');
      expect(runtime.luaState.toInteger(-1), 240);
      runtime.luaState.pop(1);
    });

    test('Lua helper module: buffer', () {
      final script = '''
        local buffer = require "buffer"
        local buf = buffer.new(10)
        _G.test_buf_size = buf:attrSize()
        buf:at(1, 65)
        _G.test_buf_at = buf:at(1)
        buf:copy(2, "BC")
        _G.test_buf_tostring = buf:toString():sub(1, 3)
        
        local buf_from_str = buffer.new("hello")
        _G.test_buf_str_size = buf_from_str:attrSize()
        _G.test_buf_str_content = buf_from_str:toString()
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_buf_size');
      expect(runtime.luaState.toInteger(-1), 10);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_buf_at');
      expect(runtime.luaState.toInteger(-1), 65);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_buf_tostring');
      expect(runtime.luaState.toStr(-1), 'ABC');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_buf_str_size');
      expect(runtime.luaState.toInteger(-1), 5);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('test_buf_str_content');
      expect(runtime.luaState.toStr(-1), 'hello');
      runtime.luaState.pop(1);
    });

    test('NCL adds settings which are consumed by Lua', () {
      const xml = '''
<ncl id="testDoc">
  <head></head>
  <body>
    <media type="application/x-ginga-settings" id="programSettings">
      <property name="user.theme" value="dark"/>
      <property name="service.currentFocus" value="0"/>
      <property name="user.age" value="25"/>
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final runtime = NCLuaRuntime(document: doc);

      runtime.execute('''
        _G.theme = settings.user.theme
        _G.focus = settings.service.currentFocus
        _G.age = settings.user.age
      ''');

      runtime.luaState.getGlobal('theme');
      expect(runtime.luaState.toStr(-1), equals('dark'));
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('focus');
      expect(runtime.luaState.toStr(-1), equals('0'));
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('age');
      expect(runtime.luaState.toStr(-1), equals('25'));
      runtime.luaState.pop(1);
    });

    test('NCL edits settings which are then consumed by Lua', () {
      const xml = '''
<ncl id="testDoc">
  <body>
    <media type="application/x-ginga-settings" id="programSettings">
      <property name="user.score" value="100"/>
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final runtime = NCLuaRuntime(document: doc);

      runtime.execute('_G.score1 = settings.user.score');
      runtime.luaState.getGlobal('score1');
      expect(runtime.luaState.toStr(-1), equals('100'));
      runtime.luaState.pop(1);

      doc.dispatchSettingsUpdate('user.score', '250');

      runtime.execute('_G.score2 = settings.user.score');
      runtime.luaState.getGlobal('score2');
      expect(runtime.luaState.toStr(-1), equals('250'));
      runtime.luaState.pop(1);
    });

    test('Lua edits settings which update NCL and can be consumed by Lua', () {
      const xml = '''
<ncl id="testDoc">
  <body>
    <media type="application/x-ginga-settings" id="programSettings">
      <property name="user.difficulty" value="easy"/>
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final runtime = NCLuaRuntime(document: doc);

      runtime.execute('_G.initDiff = settings.user.difficulty');
      runtime.luaState.getGlobal('initDiff');
      expect(runtime.luaState.toStr(-1), equals('easy'));
      runtime.luaState.pop(1);

      runtime.execute('settings.user.difficulty = "hard"');

      expect(doc.getSystemVariable('user.difficulty'), equals('hard'));

      runtime.execute('_G.updatedDiff = settings.user.difficulty');
      runtime.luaState.getGlobal('updatedDiff');
      expect(runtime.luaState.toStr(-1), equals('hard'));
      runtime.luaState.pop(1);
    });

    test('NCL dynamically adds settings via editing command consumed by Lua',
        () {
      const xml = '''
<ncl id="testDoc">
  <body>
    <media type="application/x-ginga-settings" id="programSettings"/>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final engine = NCLuaRuntime(document: doc);

      engine.execute('_G.val1 = settings.user.level');
      engine.luaState.getGlobal('val1');
      expect(engine.luaState.isNil(-1), isTrue);
      engine.luaState.pop(1);

      doc.doNclEditingCommand(
          'setPropertyValue("programSettings", "user.level", "5")');

      engine.execute('_G.val2 = settings.user.level');
      engine.luaState.getGlobal('val2');
      expect(engine.luaState.toStr(-1), equals('5'));
      engine.luaState.pop(1);
    });

    test('Lua attribution event updates properties of own NCLua media', () {
      const xml = '''
<ncl id="testDoc">
  <body>
    <media id="mScript" src="main.lua" type="application/x-ncl-NCLua">
      <property name="score" value="10"/>
    </media>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      final media = doc.getMediaById('mScript') as NCLua;
      expect(doc.getPropertyValue(media, 'score'), equals('10'));

      media.runtime.execute('''
        event.post('out', {
          class = 'ncl',
          type = 'attribution',
          name = 'score',
          value = '50',
        })
      ''');

      expect(doc.getPropertyValue(media, 'score'), equals('50'));
    });
  });
}
