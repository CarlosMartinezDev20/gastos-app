import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/receipt_scan.dart';
import '../screens/scan_screen.dart';

/// Opens the scanner above everything; returns what it read, or null when
/// closed or the user chose to type it.
typedef ScanLauncher = Future<ScanDraft?> Function(BuildContext context);

/// Overridden in tests, which have no camera.
final scanLauncherProvider = Provider<ScanLauncher>(
  (ref) =>
      (context) => Navigator.of(context, rootNavigator: true).push<ScanDraft>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ScanScreen(),
        ),
      ),
);

/// Reads the text on a receipt photo with ML Kit, on the device (no
/// upload). Only on Android and iOS.
class ReceiptReader {
  const ReceiptReader();

  bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Takes ([ImageSource.camera]) or picks a photo and returns its text, or
  /// null when the user cancels.
  Future<String?> readPhoto(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      // Enough detail for small receipt print, without huge files.
      maxWidth: 2200,
      imageQuality: 90,
    );
    if (photo == null) return null;
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      // Rebuild the printed rows from where each line sits in the photo.
      final text = receiptRows([
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(line.text, [
              for (final p in line.cornerPoints)
                (x: p.x.toDouble(), y: p.y.toDouble()),
            ]),
      ]);
      if (kDebugMode) debugPrint('[ReceiptReader] rows:\n$text');
      return text;
    } finally {
      await recognizer.close();
    }
  }
}

final receiptReaderProvider = Provider<ReceiptReader>(
  (ref) => const ReceiptReader(),
);
