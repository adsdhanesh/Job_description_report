import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

class JsonStorage {
  static const String storageKey = 'job_report_tasks_v1';

  static Future<void> save(String jsonStr) async {
    if (kIsWeb) {
      html.window.localStorage[storageKey] = jsonStr;
    } else {
      throw UnimplementedError('Non-web storage not implemented');
    }
  }

  static Future<String?> load() async {
    if (kIsWeb) {
      return html.window.localStorage[storageKey];
    } else {
      throw UnimplementedError('Non-web storage not implemented');
    }
  }

  static Future<void> clear() async {
    if (kIsWeb) {
      html.window.localStorage.remove(storageKey);
    } else {
      throw UnimplementedError('Non-web storage not implemented');
    }
  }

  static void download(String filename, String content) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body!.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
