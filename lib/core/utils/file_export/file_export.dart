// Saves a text file: a browser download on the web; elsewhere it is not
// supported and callers fall back to the clipboard.
export 'file_export_stub.dart'
    if (dart.library.js_interop) 'file_export_web.dart';
