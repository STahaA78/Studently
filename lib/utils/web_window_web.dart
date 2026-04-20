import 'dart:js_util' as js_util;

bool isPwaStandalone() {
  final dynamic window = js_util.getProperty(js_util.globalThis, 'window');
  final dynamic navigator = js_util.getProperty(window, 'navigator');
  final dynamic standalone = js_util.getProperty(navigator, 'standalone');
  return standalone == true;
}

void openUrlInNewTab(String url) {
  final dynamic window = js_util.getProperty(js_util.globalThis, 'window');
  js_util.callMethod(window, 'open', [url, '_blank']);
}
