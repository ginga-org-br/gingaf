import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

import 'tv30_keys.dart';

export 'tv30_keys.dart';

final StreamController<String> _tv30KeyController =
    StreamController<String>.broadcast();
final StreamController<double> _tv30TimeController =
    StreamController<double>.broadcast();
final StreamController<String> _tv30StreamEventController =
    StreamController<String>.broadcast();
bool _tv30ListenerInitialized = false;

void _ensureTv30Listener() {
  if (_tv30ListenerInitialized) return;
  _tv30ListenerInitialized = true;

  try {
    web.window.addEventListener(
      'message',
      (web.MessageEvent event) {
        try {
          final data = event.data;
          if (data == null) return;
          final dartified = data.dartify();
          if (dartified is Map) {
            final type = dartified['type']?.toString();
            if (type == 'tv30-aop-event') {
              final ev = dartified['event']?.toString();
              if (ev == 'keydown') {
                final key = dartified['key']?.toString();
                if (key != null && key.isNotEmpty) {
                  _tv30KeyController.add(key);
                }
              } else if (ev == 'timeupdate') {
                final detail = dartified['detail'];
                if (detail is num) {
                  _tv30TimeController.add(detail.toDouble());
                } else if (detail != null) {
                  final parsed = double.tryParse(detail.toString());
                  if (parsed != null) _tv30TimeController.add(parsed);
                }
              } else if (ev == 'stream_event') {
                final detail = dartified['detail'];
                if (detail != null) {
                  _tv30StreamEventController
                      .add(detail is String ? detail : jsonEncode(detail));
                }
              }
            } else if (dartified.containsKey('time')) {
              final t = dartified['time'];
              if (t is num) {
                _tv30TimeController.add(t.toDouble());
              } else if (t != null) {
                final parsed = double.tryParse(t.toString());
                if (parsed != null) _tv30TimeController.add(parsed);
              }
            }
          }
        } catch (e) {
          debugPrint('Error processing TV3.0 message event: $e');
        }
      }.toJS,
    );
  } catch (e) {
    debugPrint('Failed to attach TV3.0 message listener: $e');
  }
}

Stream<String> get tv30KeyStream {
  _ensureTv30Listener();
  return _tv30KeyController.stream;
}

Stream<double> get tv30TimeStream {
  _ensureTv30Listener();
  return _tv30TimeController.stream;
}

Stream<String> get tv30StreamEventStream {
  _ensureTv30Listener();
  return _tv30StreamEventController.stream;
}

void Function() subscribeTv30Testbed({
  required void Function(String nclKey) onKey,
  void Function(double time)? onTime,
  void Function(String event)? onStreamEvent,
}) {
  final keySub = tv30KeyStream.listen((rawKey) {
    final nclKey = mapTv30KeyToNclKey(rawKey);
    if (nclKey != null) {
      onKey(nclKey);
    }
  });
  final timeSub = onTime != null ? tv30TimeStream.listen(onTime) : null;
  final eventSub =
      onStreamEvent != null ? tv30StreamEventStream.listen(onStreamEvent) : null;
  return () {
    keySub.cancel();
    timeSub?.cancel();
    eventSub?.cancel();
  };
}
