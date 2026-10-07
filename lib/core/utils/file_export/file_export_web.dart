import 'dart:js_interop';

import 'package:web/web.dart' as web;

const canDownloadFiles = true;

/// Starts a browser download of [content] as [name].
Future<void> downloadTextFile(
  String name,
  String content,
  String mimeType,
) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..click();
  web.URL.revokeObjectURL(url);
}
