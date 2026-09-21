import 'package:flutter/services.dart';
import 'package:ncldoc/ncl_strings.dart';

class NclKeysFlutter {
  static LogicalKeyboardKey resolveKey(String keyName) {
    final normalized = NclKeys.normalizeKey(keyName);
    switch (normalized) {
      case NclKeys.cursorRight:
        return LogicalKeyboardKey.arrowRight;
      case NclKeys.cursorLeft:
        return LogicalKeyboardKey.arrowLeft;
      case NclKeys.cursorUp:
        return LogicalKeyboardKey.arrowUp;
      case NclKeys.cursorDown:
        return LogicalKeyboardKey.arrowDown;
      case NclKeys.enter:
        return LogicalKeyboardKey.enter;
      case NclKeys.red:
        return LogicalKeyboardKey.f1;
      case NclKeys.green:
        return LogicalKeyboardKey.f2;
      case NclKeys.yellow:
        return LogicalKeyboardKey.f3;
      case NclKeys.blue:
        return LogicalKeyboardKey.f4;
      case NclKeys.info:
        return LogicalKeyboardKey.f5;
      case NclKeys.back:
        return LogicalKeyboardKey.backspace;
      case NclKeys.exit:
        return LogicalKeyboardKey.escape;
      case '0':
        return LogicalKeyboardKey.digit0;
      case '1':
        return LogicalKeyboardKey.digit1;
      case '2':
        return LogicalKeyboardKey.digit2;
      case '3':
        return LogicalKeyboardKey.digit3;
      case '4':
        return LogicalKeyboardKey.digit4;
      case '5':
        return LogicalKeyboardKey.digit5;
      case '6':
        return LogicalKeyboardKey.digit6;
      case '7':
        return LogicalKeyboardKey.digit7;
      case '8':
        return LogicalKeyboardKey.digit8;
      case '9':
        return LogicalKeyboardKey.digit9;
      default:
        if (keyName.toUpperCase() == 'SPACE') return LogicalKeyboardKey.space;
        return LogicalKeyboardKey(keyName.hashCode);
    }
  }

  static PhysicalKeyboardKey resolvePhysicalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight) return PhysicalKeyboardKey.arrowRight;
    if (key == LogicalKeyboardKey.arrowLeft) return PhysicalKeyboardKey.arrowLeft;
    if (key == LogicalKeyboardKey.arrowUp) return PhysicalKeyboardKey.arrowUp;
    if (key == LogicalKeyboardKey.arrowDown) return PhysicalKeyboardKey.arrowDown;
    if (key == LogicalKeyboardKey.enter) return PhysicalKeyboardKey.enter;
    if (key == LogicalKeyboardKey.f1) return PhysicalKeyboardKey.f1;
    if (key == LogicalKeyboardKey.f2) return PhysicalKeyboardKey.f2;
    if (key == LogicalKeyboardKey.f3) return PhysicalKeyboardKey.f3;
    if (key == LogicalKeyboardKey.f4) return PhysicalKeyboardKey.f4;
    if (key == LogicalKeyboardKey.f5) return PhysicalKeyboardKey.f5;
    return PhysicalKeyboardKey.enter;
  }
}

LogicalKeyboardKey resolveKey(String keyName) => NclKeysFlutter.resolveKey(keyName);

PhysicalKeyboardKey resolvePhysicalKey(LogicalKeyboardKey key) =>
    NclKeysFlutter.resolvePhysicalKey(key);
