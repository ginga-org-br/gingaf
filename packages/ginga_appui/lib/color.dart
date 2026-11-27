import 'package:material_ui/material_ui.dart';

Color parseNclColor(String? raw, {Color fallback = Colors.transparent}) {
  return tryParseNclColor(raw) ?? fallback;
}

Color? tryParseNclColor(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  if (s.startsWith('#')) {
    final hex = s.substring(1);
    if (hex.length == 3) {
      final r = int.tryParse('${hex[0]}${hex[0]}', radix: 16);
      final g = int.tryParse('${hex[1]}${hex[1]}', radix: 16);
      final b = int.tryParse('${hex[2]}${hex[2]}', radix: 16);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(0xFF, r, g, b);
      }
      return null;
    } else if (hex.length == 4) {
      final r = int.tryParse('${hex[0]}${hex[0]}', radix: 16);
      final g = int.tryParse('${hex[1]}${hex[1]}', radix: 16);
      final b = int.tryParse('${hex[2]}${hex[2]}', radix: 16);
      final a = int.tryParse('${hex[3]}${hex[3]}', radix: 16);
      if (r != null && g != null && b != null && a != null) {
        return Color.fromARGB(a, r, g, b);
      }
      return null;
    } else if (hex.length == 6) {
      final v = int.tryParse('FF$hex', radix: 16);
      if (v != null) return Color(v);
      return null;
    } else if (hex.length == 8) {
      final r = int.tryParse(hex.substring(0, 2), radix: 16);
      final g = int.tryParse(hex.substring(2, 4), radix: 16);
      final b = int.tryParse(hex.substring(4, 6), radix: 16);
      final a = int.tryParse(hex.substring(6, 8), radix: 16);
      if (r != null && g != null && b != null && a != null) {
        return Color.fromARGB(a, r, g, b);
      }
      return null;
    }
    return null;
  }

  final lower = s.toLowerCase();
  if ((lower.startsWith('rgb(') || lower.startsWith('rgba(')) &&
      lower.endsWith(')')) {
    final isRgba = lower.startsWith('rgba(');
    final inner = s.substring(isRgba ? 5 : 4, s.length - 1);
    final parts = inner.split(',');
    if ((!isRgba && parts.length == 3) || (isRgba && parts.length == 4)) {
      final r = _parseColorChannel(parts[0]);
      final g = _parseColorChannel(parts[1]);
      final b = _parseColorChannel(parts[2]);
      final a = isRgba ? _parseAlphaChannel(parts[3]) : 255;
      if (r != null && g != null && b != null && a != null) {
        return Color.fromARGB(a, r, g, b);
      }
    }
    return null;
  }

  switch (lower) {
    case 'transparent':
      return const Color(0x00000000);
    case 'white':
      return const Color(0xFFFFFFFF);
    case 'black':
      return const Color(0xFF000000);
    case 'silver':
      return const Color(0xFFC0C0C0);
    case 'gray':
      return const Color(0xFF808080);
    case 'red':
      return const Color(0xFFFF0000);
    case 'maroon':
      return const Color(0xFF800000);
    case 'fuchsia':
      return const Color(0xFFFF00FF);
    case 'purple':
      return const Color(0xFF800080);
    case 'lime':
      return const Color(0xFF00FF00);
    case 'green':
      return const Color(0xFF008000);
    case 'yellow':
      return const Color(0xFFFFFF00);
    case 'olive':
      return const Color(0xFF808000);
    case 'blue':
      return const Color(0xFF0000FF);
    case 'navy':
      return const Color(0xFF000080);
    case 'aqua':
      return const Color(0xFF00FFFF);
    case 'teal':
      return const Color(0xFF008080);
    default:
      return null;
  }
}

int? _parseColorChannel(String raw) {
  final s = raw.trim();
  if (s.endsWith('%')) {
    final pct = double.tryParse(s.substring(0, s.length - 1).trim());
    if (pct == null) return null;
    return ((pct.clamp(0.0, 100.0) / 100.0) * 255).round().clamp(0, 255);
  }
  final val = double.tryParse(s);
  if (val == null) return null;
  return val.round().clamp(0, 255);
}

int? _parseAlphaChannel(String raw) {
  final s = raw.trim();
  if (s.endsWith('%')) {
    final pct = double.tryParse(s.substring(0, s.length - 1).trim());
    if (pct == null) return null;
    return ((pct.clamp(0.0, 100.0) / 100.0) * 255).round().clamp(0, 255);
  }
  final val = double.tryParse(s);
  if (val == null) return null;
  if (val <= 1.0 && (s.contains('.') || val == 0.0 || val == 1.0)) {
    return (val.clamp(0.0, 1.0) * 255).round().clamp(0, 255);
  }
  return val.round().clamp(0, 255);
}

int? tryParseNclTransparencyToAlpha(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.endsWith('%')) {
    final pct = double.tryParse(s.substring(0, s.length - 1).trim());
    if (pct == null) return null;
    final t = (pct / 100.0).clamp(0.0, 1.0);
    return ((1.0 - t) * 255).round().clamp(0, 255);
  }
  final val = double.tryParse(s);
  if (val == null) return null;
  if (val <= 1.0 && (s.contains('.') || val == 0.0 || val == 1.0)) {
    final t = val.clamp(0.0, 1.0);
    return ((1.0 - t) * 255).round().clamp(0, 255);
  }
  return (255 - val.round()).clamp(0, 255);
}

int? tryParseNclAlpha(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.endsWith('%')) {
    final pct = double.tryParse(s.substring(0, s.length - 1).trim());
    if (pct == null) return null;
    return ((pct.clamp(0.0, 100.0) / 100.0) * 255).round().clamp(0, 255);
  }
  final val = double.tryParse(s);
  if (val == null) return null;
  if (val < 1.0 && s.contains('.')) {
    return (val.clamp(0.0, 1.0) * 255).round().clamp(0, 255);
  }
  return val.round().clamp(0, 255);
}
