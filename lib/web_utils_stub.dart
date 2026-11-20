String? getGingaApp() => null;

bool? getGingaPlayground() => null;

void notifyParentAppExited() {}

bool isTv30Testbed() => false;

String? mapTv30TestbedKeyToNclKey(String rawKey) => null;

Future<void Function()?> attachTv30Testbed({
  required void Function(String nclKey) onKey,
  void Function(double time)? onTime,
  void Function(String event)? onStreamEvent,
}) async =>
    null;
