bool? parseBoolFlag(String? raw) {
  if (raw == null) return null;
  final lower = raw.trim().toLowerCase();
  if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on') {
    return true;
  }
  if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'off') {
    return false;
  }
  return null;
}

List<int>? parseBreakpoints(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final result = <int>[];
  for (final part in raw.split(RegExp(r'[\s,]+'))) {
    final parsed = int.tryParse(part.trim());
    if (parsed != null) {
      result.add(parsed);
    }
  }
  return result;
}

String normalizeRemoteDeviceClass(String raw) {
  final trimmed = raw.trim();
  if (trimmed == 'acessibility') return 'accessibility';
  return trimmed;
}

List<String>? parseRemoteDevices(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = raw
      .split(',')
      .map(normalizeRemoteDeviceClass)
      .where((s) => s.isNotEmpty)
      .toList();
  return parsed.isNotEmpty ? parsed : null;
}

const List<String> remoteDeviceParamKeys = [
  'remote-devices',
  'remote_devices',
  'remoteDevices',
  'GINGA_REMOTE_DEVICES',
  'ginga_remote_devices',
];

String? lookupQueryParam(Map<String, String> params, List<String> keys) {
  for (final key in keys) {
    final val = params[key];
    if (val != null && val.trim().isNotEmpty) {
      return val.trim();
    }
  }
  return null;
}

List<String> extractRemoteDevicesFromSrc(String? src) {
  if (src == null || !src.contains('?')) return const [];
  final qIdx = src.indexOf('?');
  final queryPart = src.substring(qIdx + 1).split('#').first;
  try {
    final params = Uri.splitQueryString(queryPart);
    final raw = lookupQueryParam(params, remoteDeviceParamKeys);
    return parseRemoteDevices(raw) ?? const [];
  } catch (_) {
    return const [];
  }
}

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

  for (final key in remoteDeviceParamKeys) {
    nextParams.remove(key);
  }

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
