import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ginga_app/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLua Runtime Tests', () {
    late NclDocument doc;
    late NCLuaRuntime runtime;
    setUp(() {
      doc = NclDocument.fromContent('<ncl><head/><body/></ncl>');
      runtime = NCLuaRuntime(document: doc);
    });

    tearDown(() {
      runtime.dispose();
      doc.appContext.dispose();
      doc.pbds.dispose();
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
          'broadcastfs', 'mediakeysession', 'pbds', 'pds', 'user'
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
        'key',
        'pointer',
        'ncl',
        'edit',
        'tcp',
        'udp',
        'http',
        'sms',
        'si',
        'sectionfilter',
        'pesfilter',
        'tpfilter',
        'zip',
        'streambuf',
        'broadcastfs',
        'mediakeysession',
        'pbds',
        'pds',
        'user'
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

        local okOpen = pbds.open()
        local okAct = pbds.activate()
        local okSave = pbds.save()
        local okWrite = pbds.write("greeting.txt", "hello pbds")
        local readVal = pbds.read("greeting.txt")
        local existsBefore = pbds.exists("greeting.txt")
        local entries = pbds.list()
        local bases = pbds.listBases()
        local okAddDoc = pbds.addDocument("doc_aux", "aux.ncl", "<ncl id='doc_aux'/>")
        local okStartDoc = pbds.startDocument("doc_aux")
        local docStarted = pbds.getDocument("doc_aux")
        local okPauseDoc = pbds.pauseDocument("doc_aux")
        local docPaused = pbds.getDocument("doc_aux")
        local okResumeDoc = pbds.resumeDocument("doc_aux")
        local docResumed = pbds.getDocument("doc_aux")
        local okStopDoc = pbds.stopDocument("doc_aux")
        local docStopped = pbds.getDocument("doc_aux")
        local docs = pbds.listDocuments()
        local info = pbds.info()
        local okRemEntry = pbds.remove("greeting.txt")
        local existsAfter = pbds.exists("greeting.txt")
        local okRemDoc = pbds.removeDocument("doc_aux")
        local okDeact = pbds.deactivate()
        local okClose = pbds.close()

        _G.pbds_ok = okOpen and okAct and okSave and okWrite and existsBefore
          and okAddDoc and okStartDoc and okPauseDoc and okResumeDoc
          and okStopDoc and okRemEntry and (not existsAfter) and okRemDoc
          and okDeact and okClose
        _G.pbds_read = readVal
        _G.pbds_entries_count = #entries
        _G.pbds_bases_count = #bases
        _G.pbds_doc_state_started = docStarted and docStarted.state
        _G.pbds_doc_state_paused = docPaused and docPaused.state
        _G.pbds_doc_state_resumed = docResumed and docResumed.state
        _G.pbds_doc_state_stopped = docStopped and docStopped.state
        _G.pbds_docs_count = #docs
        _G.pbds_info_persistent = info and info.persistent
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('test_pbds_exists');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_ok');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_read');
      expect(runtime.luaState.toStr(-1), 'hello pbds');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_entries_count');
      expect(runtime.luaState.toInteger(-1), 1);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_bases_count');
      expect(runtime.luaState.toInteger(-1), 1);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_doc_state_started');
      expect(runtime.luaState.toStr(-1), 'occurring');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_doc_state_paused');
      expect(runtime.luaState.toStr(-1), 'paused');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_doc_state_resumed');
      expect(runtime.luaState.toStr(-1), 'occurring');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_doc_state_stopped');
      expect(runtime.luaState.toStr(-1), 'sleeping');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_docs_count');
      expect(runtime.luaState.toInteger(-1), 2);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('pbds_info_persistent');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);
    });

    test(
        'Lua event class pbds and pds lifecycle, documents, storage, and errors',
        () {
      final script = '''
        local event = require "event"
        local received = {}
        event.register(function(evt)
          if evt.class == "pbds" or evt.class == "pds" then
            table.insert(received, evt)
          end
        end)

        event.post({ class = "pbds", type = "open", requestId = "r1" })
        event.post({ class = "pbds", type = "activate", requestId = "r2" })
        event.post({ class = "pbds", type = "write", path = "cfg/app.json", data = '{"v":1}', requestId = "r3" })
        event.post({ class = "pbds", type = "read", path = "cfg/app.json", requestId = "r4" })
        event.post({ class = "pbds", type = "exists", path = "cfg/app.json", requestId = "r5" })
        event.post({ class = "pbds", type = "list", path = "cfg", requestId = "r6" })
        event.post({ class = "pbds", type = "addDocument", docId = "d1", uri = "d1.ncl", requestId = "r7" })
        event.post({ class = "pbds", type = "startDocument", docId = "d1", requestId = "r8" })
        event.post({ class = "pbds", type = "getDocument", docId = "d1", requestId = "r9" })
        event.post({ class = "pbds", type = "stopDocument", docId = "d1", requestId = "r10" })
        event.post({ class = "pds", type = "info", requestId = "r11" })
        event.post({ class = "pbds", type = "remove", path = "cfg/app.json", requestId = "r12" })
        event.post({ class = "pbds", type = "close", requestId = "r13" })
        event.post({ class = "pbds", type = "read", path = "cfg/app.json", requestId = "r14" })
        event.post({ class = "pbds", type = "open", requestId = "r15" })
        event.post({ class = "pbds", type = "unknownOp", requestId = "r16" })
        event.post({ class = "pbds", type = "read", baseId = "other_base", path = "cfg/app.json", requestId = "r17" })

        _G.pbds_count = #received
        _G.r1_state = received[1] and received[1].state
        _G.r1_req = received[1] and received[1].requestId
        _G.r2_state = received[2] and received[2].state
        _G.r4_data = received[4] and received[4].data
        _G.r5_exists = received[5] and received[5].exists
        _G.r6_first = received[6] and received[6].entries and received[6].entries[1]
        _G.r8_state = received[8] and received[8].state
        _G.r9_uri = received[9] and received[9].uri
        _G.r10_state = received[10] and received[10].state
        _G.r11_class = received[11] and received[11].class
        _G.r11_ok = received[11] and received[11].ok
        _G.r12_ok = received[12] and received[12].ok
        _G.r13_state = received[13] and received[13].state
        _G.r14_ok = received[14] and received[14].ok
        _G.r14_err = received[14] and received[14].error
        _G.r16_ok = received[16] and received[16].ok
        _G.r16_err = received[16] and received[16].error
        _G.r17_ok = received[17] and received[17].ok
        _G.r17_err = received[17] and received[17].error
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('pbds_count');
      expect(runtime.luaState.toInteger(-1), 17);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r1_state');
      expect(runtime.luaState.toStr(-1), 'open');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r1_req');
      expect(runtime.luaState.toStr(-1), 'r1');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r2_state');
      expect(runtime.luaState.toStr(-1), 'active');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r4_data');
      expect(runtime.luaState.toStr(-1), '{"v":1}');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r5_exists');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r6_first');
      expect(runtime.luaState.toStr(-1), 'app.json');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r8_state');
      expect(runtime.luaState.toStr(-1), 'occurring');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r9_uri');
      expect(runtime.luaState.toStr(-1), 'd1.ncl');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r10_state');
      expect(runtime.luaState.toStr(-1), 'sleeping');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r11_class');
      expect(runtime.luaState.toStr(-1), 'pds');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r11_ok');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r12_ok');
      expect(runtime.luaState.toBoolean(-1), true);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r13_state');
      expect(runtime.luaState.toStr(-1), 'closed');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r14_ok');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r14_err');
      expect(runtime.luaState.toStr(-1), contains('private base is closed'));
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r16_ok');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r16_err');
      expect(runtime.luaState.toStr(-1), contains('unknown pbds event type'));
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r17_ok');
      expect(runtime.luaState.toBoolean(-1), false);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('r17_err');
      expect(runtime.luaState.toStr(-1), contains('private base not found'));
      runtime.luaState.pop(1);
    });

    test(
        'Lua pbds events control active NclDocument, editing commands, and disk files',
        () {
      final tempDir = Directory.systemTemp.createTempSync('ginga_lua_pbds_');
      try {
        final nclFile = File('${tempDir.path}/main.ncl');
        const nclXml = '''
<ncl id="pbdsApp">
  <head>
    <regionBase id="rb1">
      <region id="r1" width="100%" height="100%"/>
    </regionBase>
  </head>
  <body id="body1">
    <port id="p1" component="m1"/>
    <media id="m1" type="text/plain"/>
  </body>
</ncl>
''';
        nclFile.writeAsStringSync(nclXml);

        final doc = NclDocument.fromContent(
          nclXml,
          applicationId: 'pbdsApp',
          appSrc: nclFile.path,
        );
        doc.start();
        final diskRuntime = NCLuaRuntime(document: doc, src: nclFile.path);
        addTearDown(diskRuntime.dispose);

        diskRuntime.execute('''
          local event = require "event"
          local events = {}
          event.register(function(evt)
            if evt.class == "pbds" then
              table.insert(events, evt)
            end
          end)

          event.post({ class = "pbds", type = "write", path = "saved.txt", data = "disk-content" })
          event.post({ class = "pbds", type = "read", path = "saved.txt" })
          event.post({ class = "pbds", type = "resolve", path = "saved.txt" })
          event.post({ class = "pbds", type = "pauseDocument", docId = "pbdsApp" })
          event.post({ class = "pbds", type = "resumeDocument", docId = "pbdsApp" })
          event.post({
            class = "pbds",
            type = "edit",
            command = 'addNode(body1, <media id="m2" type="text/plain"/>)'
          })

          _G.disk_write_ok = events[1] and events[1].ok
          _G.disk_read_data = events[2] and events[2].data
          _G.disk_resolved = events[3] and events[3].uri
          _G.doc_paused_state = events[4] and events[4].state
          _G.doc_resumed_state = events[5] and events[5].state
          _G.edit_ok = events[6] and events[6].ok
        ''');

        expect(File('${tempDir.path}/saved.txt').existsSync(), isTrue);
        expect(File('${tempDir.path}/saved.txt').readAsStringSync(),
            'disk-content');

        diskRuntime.luaState.getGlobal('disk_write_ok');
        expect(diskRuntime.luaState.toBoolean(-1), true);
        diskRuntime.luaState.pop(1);

        diskRuntime.luaState.getGlobal('disk_read_data');
        expect(diskRuntime.luaState.toStr(-1), 'disk-content');
        diskRuntime.luaState.pop(1);

        diskRuntime.luaState.getGlobal('disk_resolved');
        expect(diskRuntime.luaState.toStr(-1), endsWith('/saved.txt'));
        diskRuntime.luaState.pop(1);

        diskRuntime.luaState.getGlobal('doc_paused_state');
        expect(diskRuntime.luaState.toStr(-1), 'paused');
        diskRuntime.luaState.pop(1);

        diskRuntime.luaState.getGlobal('doc_resumed_state');
        expect(diskRuntime.luaState.toStr(-1), 'occurring');
        diskRuntime.luaState.pop(1);

        diskRuntime.luaState.getGlobal('edit_ok');
        expect(diskRuntime.luaState.toBoolean(-1), true);
        diskRuntime.luaState.pop(1);

        expect(doc.getNodeById('m2'), isNotNull);
        expect(doc.isPaused, isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
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

    test(
        'Lua helper module: zip (virtual archive read, append, remove, extract)',
        () {
      final initialArchive = Archive()
        ..add(ArchiveFile.string('main.lua', 'return 42'))
        ..add(ArchiveFile.string('assets/info.txt', 'ginga zip'));
      final zipBytes = ZipEncoder().encodeBytes(initialArchive);

      final zipDoc = NclDocument.fromContent(
        '<ncl><head/><body/></ncl>',
        applicationId: 'zip_virtual_test',
        virtualFiles: {
          'test.zip': 'data:application/zip;base64,${base64.encode(zipBytes)}',
        },
      );
      final zipRuntime = NCLuaRuntime(document: zipDoc);
      addTearDown(() {
        zipRuntime.dispose();
        zipDoc.appContext.dispose();
      });

      final script = '''
        local zip = require "zip"
        local missing, missing_err = zip.open("does_not_exist.zip")
        _G.test_zip_missing_is_nil = (missing == nil)
        _G.test_zip_missing_has_err = (type(missing_err) == "string")

        local z = zip.open("test.zip")
        _G.test_zip_path = z:attrPath()
        _G.test_zip_exists_before = z:exists("main.lua")
        _G.test_zip_read_main = z:read("main.lua")
        z:append("newfile.txt", "data_payload")
        _G.test_zip_exists_after = z:exists("newfile.txt")
        _G.test_zip_read_new = z:read("newfile.txt")
        _G.test_zip_remove_ok = z:remove("main.lua")
        _G.test_zip_exists_after_remove = z:exists("main.lua")
        _G.test_zip_extract_ok = z:extract("assets/info.txt", "extracted_info.txt")
        z:close()

        local z2 = zip.open("test.zip")
        _G.test_zip_persisted_new = z2:exists("newfile.txt")
        _G.test_zip_persisted_removed = z2:exists("main.lua")
        local list = z2:list()
        _G.test_zip_list_count = #list
        z2:close()

        local f = io.open("extracted_info.txt", "r")
        _G.test_zip_extracted_content = f and f:read("*a") or nil
      ''';
      zipRuntime.execute(script);

      zipRuntime.luaState.getGlobal('test_zip_missing_is_nil');
      expect(zipRuntime.luaState.toBoolean(-1), isTrue);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_missing_has_err');
      expect(zipRuntime.luaState.toBoolean(-1), isTrue);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_path');
      expect(zipRuntime.luaState.toStr(-1), 'test.zip');
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_exists_before');
      expect(zipRuntime.luaState.toBoolean(-1), true);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_read_main');
      expect(zipRuntime.luaState.toStr(-1), 'return 42');
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_exists_after');
      expect(zipRuntime.luaState.toBoolean(-1), true);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_read_new');
      expect(zipRuntime.luaState.toStr(-1), 'data_payload');
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_remove_ok');
      expect(zipRuntime.luaState.toBoolean(-1), true);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_exists_after_remove');
      expect(zipRuntime.luaState.toBoolean(-1), false);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_extract_ok');
      expect(zipRuntime.luaState.toBoolean(-1), true);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_persisted_new');
      expect(zipRuntime.luaState.toBoolean(-1), true);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_persisted_removed');
      expect(zipRuntime.luaState.toBoolean(-1), false);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_list_count');
      expect(zipRuntime.luaState.toInteger(-1), 2);
      zipRuntime.luaState.pop(1);

      zipRuntime.luaState.getGlobal('test_zip_extracted_content');
      expect(zipRuntime.luaState.toStr(-1), 'ginga zip');
      zipRuntime.luaState.pop(1);
    });

    test(
        'Lua helper module: zip (filesystem archive create, read, and extractAll)',
        () {
      final tmpDir = Directory.systemTemp.createTempSync('nclua_zip_test_');
      addTearDown(() {
        if (tmpDir.existsSync()) {
          tmpDir.deleteSync(recursive: true);
        }
      });

      final zipPath = '${tmpDir.path.replaceAll('\\', '/')}/bundle.zip';
      final extractDir = '${tmpDir.path.replaceAll('\\', '/')}/unpacked';

      final script = '''
        local zip = require "zip"
        local z = zip.open("$zipPath", "w")
        z:append("hello.txt", "Hello Filesystem Zip")
        z:append("nested/config.json", "{\\"ok\\":true}")
        z:append("temp.txt", "remove me")
        z:remove("temp.txt")
        z:close()

        local zRead = zip.open("$zipPath", "r")
        _G.fs_zip_hello = zRead:read("hello.txt")
        _G.fs_zip_extract_all = zRead:extractAll("$extractDir")
        zRead:close()
      ''';
      runtime.execute(script);

      runtime.luaState.getGlobal('fs_zip_hello');
      expect(runtime.luaState.toStr(-1), 'Hello Filesystem Zip');
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('fs_zip_extract_all');
      expect(runtime.luaState.toBoolean(-1), isTrue);
      runtime.luaState.pop(1);

      final zipFile = File(zipPath);
      expect(zipFile.existsSync(), isTrue);
      final decoded = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
      final names = decoded.files.map((f) => f.name).toList();
      expect(names, containsAll(['hello.txt', 'nested/config.json']));
      expect(names, isNot(contains('temp.txt')));

      expect(
        File('$extractDir/hello.txt').readAsStringSync(),
        'Hello Filesystem Zip',
      );
      expect(
        File('$extractDir/nested/config.json').readAsStringSync(),
        '{"ok":true}',
      );
    });

    test('Lua helper module: zip (remote HTTP URL in headless NCLuaRuntime)',
        () async {
      final prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() {
        HttpOverrides.global = prevOverrides;
      });
      final archive = Archive()
        ..add(ArchiveFile.string('remote.txt', 'Loaded over HTTP'));
      final zipBytes = ZipEncoder().encodeBytes(archive);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((req) {
        if (req.uri.path == '/remote.zip') {
          req.response.statusCode = 200;
          req.response.headers.set('content-type', 'application/zip');
          req.response.add(zipBytes);
        } else {
          req.response.statusCode = 404;
        }
        req.response.close();
      });

      final url = 'http://127.0.0.1:${server.port}/remote.zip';
      await runtime.execute('''
        local zip = require "zip"
        local z = zip.open("$url", "r")
        _G.http_zip_ok = (z ~= nil)
        _G.http_zip_content = z and z:read("remote.txt") or nil
        if z then z:close() end
      ''');

      runtime.luaState.getGlobal('http_zip_ok');
      expect(runtime.luaState.toBoolean(-1), isTrue);
      runtime.luaState.pop(1);

      runtime.luaState.getGlobal('http_zip_content');
      expect(runtime.luaState.toStr(-1), 'Loaded over HTTP');
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
    <media type="application/x-ginga-settings" id="mSttgs">
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
    <media type="application/x-ginga-settings" id="mSttgs">
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
    <media type="application/x-ginga-settings" id="mSttgs">
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
    <media type="application/x-ginga-settings" id="mSttgs"/>
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

      doc.doNclEditingCommand('setPropertyValue("mSttgs", "user.level", "5")');

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
