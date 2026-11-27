import 'arg_parsers.dart';

export 'arg_parsers.dart' show buildGingaBrowserUrl;

String? getGingaApp() => null;

bool? getGingaPlayground() => null;

List<String>? getGingaRemoteDevices() => null;

String? lastSyncedBrowserUrl;

void updateGingaBrowserUrl(
  String selectedFile, {
  String? resolvedAppUrl,
}) {
  lastSyncedBrowserUrl = buildGingaBrowserUrl(
    lastSyncedBrowserUrl ?? 'http://localhost/playground',
    selectedFile,
    resolvedAppUrl: resolvedAppUrl,
  );
}

void notifyParentAppExited() {}

bool isTv30Testbed() => false;

String? mapTv30TestbedKeyToNclKey(String rawKey) => null;

Future<void Function()?> attachTv30Testbed({
  required void Function(String nclKey) onKey,
  void Function(double time)? onTime,
  void Function(String event)? onStreamEvent,
}) async =>
    null;
