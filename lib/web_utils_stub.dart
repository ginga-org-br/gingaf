String? getGingaApp() => null;

bool? getGingaPlayground() => null;

List<String>? getGingaRemoteDevices() => null;

String? lastSyncedBrowserUrl;

String buildGingaBrowserUrl(
  String currentHref,
  String selectedFile, {
  String? resolvedAppUrl,
}) {
  final current = Uri.parse(currentHref);
  final qIdx = selectedFile.indexOf('?');
  final rawPath = qIdx != -1 ? selectedFile.substring(0, qIdx) : selectedFile;
  final appValue = (resolvedAppUrl != null && resolvedAppUrl.isNotEmpty)
      ? resolvedAppUrl.split('?').first
      : rawPath;
  final nextParams = Map<String, String>.from(current.queryParameters);
  nextParams.remove('ginga_app');
  nextParams.remove('src');
  nextParams.remove('appSrc');
  nextParams['app'] = appValue;

  nextParams.remove('remote-devices');
  nextParams.remove('remote_devices');
  nextParams.remove('remoteDevices');
  nextParams.remove('GINGA_REMOTE_DEVICES');
  nextParams.remove('ginga_remote_devices');

  if (qIdx != -1) {
    final extraQuery = selectedFile.substring(qIdx + 1).split('#').first;
    final extraParams = Uri.splitQueryString(extraQuery);
    for (final entry in extraParams.entries) {
      nextParams[entry.key] = entry.value;
    }
  }

  final rawQuery = nextParams.entries.map((e) {
    final encodedKey = Uri.encodeQueryComponent(e.key);
    final encodedVal = Uri.encodeQueryComponent(e.value)
        .replaceAll('%3A', ':')
        .replaceAll('%3a', ':')
        .replaceAll('%2F', '/')
        .replaceAll('%2f', '/')
        .replaceAll('%2C', ',')
        .replaceAll('%2c', ',');
    return '$encodedKey=$encodedVal';
  }).join('&');

  return current.replace(query: rawQuery).toString();
}

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
