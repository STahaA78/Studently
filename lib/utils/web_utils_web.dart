import 'package:js/js_util.dart' as js_util;
import 'package:studently/logger.dart';
import 'package:flutter/foundation.dart';

bool isStandalonePwa() {
  if (!kIsWeb) return false;
  try {
    final dynamic window = js_util.getProperty(js_util.globalThis, 'window');
    final dynamic navigator = js_util.getProperty(window, 'navigator');
    final dynamic standalone = js_util.getProperty(navigator, 'standalone');
    return standalone == true;
  } catch (e) {
    logger.w('Error checking PWA status: $e');
    return false;
  }
}

void openInNewTab(String url) {
  try {
    final dynamic window = js_util.getProperty(js_util.globalThis, 'window');
    js_util.callMethod(window, 'open', [url, '_blank']);
  } catch (e) {
    logger.w('Error opening URL in new tab: $e');
  }
}
