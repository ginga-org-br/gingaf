import 'dart:html' as html;

String? getSessionStorageItem(String key) {
  try {
    return html.window.sessionStorage[key];
  } catch (e) {
    return null;
  }
}

void notifyParentAppExited() {
  try {
    html.window.parent?.postMessage('ginga_app_exited', '*');
  } catch (e) {
    // ignore
  }
}
