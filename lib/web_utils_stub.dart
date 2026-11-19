export 'tv30_keys.dart';

String? getGingaApp() => null;

bool? getGingaPlayground() => null;

void notifyParentAppExited() {}

bool isTv30Mode() => false;

Future<void Function()?> attachTv30Testbed({
  required void Function(String nclKey) onKey,
  void Function(double time)? onTime,
  void Function(String event)? onStreamEvent,
}) async =>
    null;
