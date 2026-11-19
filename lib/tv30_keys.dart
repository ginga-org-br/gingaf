String? mapTv30KeyToNclKey(String rawKey) {
  final k = rawKey.trim();
  final lower = k.toLowerCase();
  if (lower == 'arrowup' || lower == 'up') return 'UP';
  if (lower == 'arrowdown' || lower == 'down') return 'DOWN';
  if (lower == 'arrowleft' || lower == 'left') return 'LEFT';
  if (lower == 'arrowright' || lower == 'right') return 'RIGHT';
  if (lower == 'enter' || lower == 'select' || lower == 'ok') return 'ENTER';
  if (lower == 'f1' ||
      lower == 'red' ||
      lower == 'r' ||
      lower == 'colorf0red') {
    return 'RED';
  }
  if (lower == 'f2' ||
      lower == 'green' ||
      lower == 'g' ||
      lower == 'colorf1green') {
    return 'GREEN';
  }
  if (lower == 'f3' ||
      lower == 'yellow' ||
      lower == 'y' ||
      lower == 'colorf2yellow') {
    return 'YELLOW';
  }
  if (lower == 'f4' ||
      lower == 'blue' ||
      lower == 'b' ||
      lower == 'colorf3blue') {
    return 'BLUE';
  }
  if (lower == 'f5' || lower == 'info' || lower == 'i') return 'INFO';
  if (lower == 'escape' || lower == 'back' || lower == 'exit') return 'ESCAPE';
  if (RegExp(r'^[0-9]$').hasMatch(k)) return k;
  return null;
}
