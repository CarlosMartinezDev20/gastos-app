import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../core/utils/receipt_scan.dart';
import '../services/receipt_scanner.dart';
import '../widgets/mascot.dart';

/// Full-screen camera that reads an invoice's or a payment's QR, or the
/// total printed on a receipt photo. Pops a [ScanDraft], or null to type the
/// expense by hand.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

enum _Stage { scanning, invoiceFound, reading }

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  var _stage = _Stage.scanning;
  ScanDraft? _invoice;

  /// A short note in the bottom panel (an unusable code, an unreadable
  /// photo).
  String? _note;

  /// The camera failed for lack of permission: retried when the user comes
  /// back from the system settings.
  var _permissionMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionMissing) {
      _retryCamera();
    }
  }

  Future<void> _retryCamera() async {
    if (!await Permission.camera.isGranted) return;
    _permissionMissing = false;
    await _camera.start();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_stage != _Stage.scanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final draft = parseQrPayload(raw);
    if (draft == null) {
      setState(
        () => _note =
            'Ese código no tiene datos de un gasto. Prueba con el QR '
            'de la factura o lee el ticket con una foto.',
      );
      return;
    }
    if (draft.source == ScanSource.invoice && draft.amount == null) {
      // Hacienda's QR has no amount: offer to read it from the receipt.
      setState(() {
        _invoice = draft;
        _stage = _Stage.invoiceFound;
        _note = null;
      });
      return;
    }
    Navigator.pop(context, draft);
  }

  Future<void> _readPhoto(ImageSource source) async {
    final reader = ref.read(receiptReaderProvider);
    setState(() {
      _stage = _Stage.reading;
      _note = null;
    });
    // The picker opens its own camera: release ours meanwhile.
    await _camera.stop();
    String? text;
    try {
      text = await reader.readPhoto(source);
    } catch (_) {
      text = null;
    }
    if (!mounted) return;
    final read = text == null ? null : parseReceiptText(text);
    final draft = switch ((_invoice, read)) {
      (final invoice?, final read?) => invoice.merge(read),
      (final invoice?, null) => invoice,
      (null, final read?) => read,
      (null, null) => null,
    };
    if (draft != null && !(read?.isEmpty ?? true)) {
      Navigator.pop(context, draft);
      return;
    }
    // Cancelled or nothing legible: back to where the user was.
    setState(() {
      _stage = _invoice == null ? _Stage.scanning : _Stage.invoiceFound;
      _note = text == null
          ? null
          : 'No pude leer el ticket. Prueba con más luz, sin arrugas, o '
                'escríbelo a mano.';
    });
    if (!_permissionMissing) await _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    final reader = ref.watch(receiptReaderProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              final denied =
                  error.errorCode == MobileScannerErrorCode.permissionDenied;
              _permissionMissing = denied;
              return _CameraProblem(
                denied: denied,
                onRetry: _retryCamera,
                onPickPhoto: reader.available
                    ? () => _readPhoto(ImageSource.gallery)
                    : null,
              );
            },
          ),
          const IgnorePointer(child: _Viewfinder()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _RoundIcon(
                    icon: CupertinoIcons.xmark,
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  ValueListenableBuilder(
                    valueListenable: _camera,
                    builder: (context, state, _) =>
                        state.torchState == TorchState.unavailable
                        ? const SizedBox.shrink()
                        : _RoundIcon(
                            icon: state.torchState == TorchState.on
                                ? CupertinoIcons.bolt_fill
                                : CupertinoIcons.bolt_slash,
                            tooltip: 'Linterna',
                            onPressed: _camera.toggleTorch,
                          ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Panel(
              stage: _stage,
              invoice: _invoice,
              note: _note,
              canReadPhoto: reader.available,
              onReadPhoto: () => _readPhoto(ImageSource.camera),
              onContinue: () => Navigator.pop(context, _invoice),
              onManual: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.stage,
    required this.invoice,
    required this.note,
    required this.canReadPhoto,
    required this.onReadPhoto,
    required this.onContinue,
    required this.onManual,
  });

  final _Stage stage;
  final ScanDraft? invoice;
  final String? note;
  final bool canReadPhoto;
  final VoidCallback onReadPhoto;
  final VoidCallback onContinue;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final (title, subtitle) = switch (stage) {
      _Stage.scanning => (
        'Apunta al código QR',
        'El de tu factura electrónica o el código de pago de un comercio.',
      ),
      _Stage.invoiceFound => (
        invoice?.date == null
            ? 'Factura encontrada'
            : 'Factura del ${DateFormat("d 'de' MMMM", 'es').format(invoice!.date!)}',
        'El QR de Hacienda no trae el monto. Puedo leerlo del ticket o lo '
            'escribes tú.',
      ),
      _Stage.reading => ('Leyendo el ticket…', 'Busco el total y el comercio.'),
    };
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: AnimatedSize(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.standard,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (stage == _Stage.reading)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (stage == _Stage.invoiceFound)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: palette.onMint,
                    ),
                  ),
                Expanded(child: Text(title, style: text.titleLarge)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: palette.muted)),
            if (note != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.blush,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  note!,
                  style: TextStyle(
                    color: palette.onBlush,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (stage != _Stage.reading) ...[
              const SizedBox(height: 16),
              if (canReadPhoto)
                FilledButton.icon(
                  onPressed: onReadPhoto,
                  icon: const Icon(CupertinoIcons.doc_text_viewfinder),
                  label: Text(
                    stage == _Stage.invoiceFound
                        ? 'Leer el total del ticket'
                        : 'Leer ticket con una foto',
                  ),
                ),
              const SizedBox(height: 8),
              if (stage == _Stage.invoiceFound)
                OutlinedButton(
                  onPressed: onContinue,
                  child: const Text('Escribir el monto yo'),
                )
              else
                TextButton(
                  onPressed: onManual,
                  child: const Text('Escribir a mano'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dims the camera around a rounded square with lime corners.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ViewfinderPainter(context.palette.accent));
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final side = (size.shortestSide * .68).clamp(180.0, 320.0);
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .38),
        width: side,
        height: side,
      ),
      const Radius.circular(28),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Colors.black.withValues(alpha: .55),
    );
    final corner = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const arm = 34.0;
    final r = hole.outerRect;
    for (final (x, y, dx, dy) in [
      (r.left, r.top, 1.0, 1.0),
      (r.right, r.top, -1.0, 1.0),
      (r.left, r.bottom, 1.0, -1.0),
      (r.right, r.bottom, -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(Offset(x, y + dy * 14), Offset(x, y + dy * arm), corner)
        ..drawLine(Offset(x + dx * 14, y), Offset(x + dx * arm, y), corner);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({
    required this.denied,
    required this.onRetry,
    required this.onPickPhoto,
  });

  final bool denied;
  final Future<void> Function() onRetry;
  final VoidCallback? onPickPhoto;

  Future<void> _askPermission() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      // The system won't ask again: only the settings can grant it.
      await openAppSettings();
    } else if (status.isGranted) {
      await onRetry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 260),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(mood: MascotMood.worried, size: 96),
                const SizedBox(height: 16),
                Text(
                  denied
                      ? 'Necesito la cámara para escanear'
                      : 'No encontré una cámara disponible',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  denied
                      ? 'Solo la uso mientras escaneas; las fotos se leen en '
                            'tu teléfono y no se suben.'
                      : 'Puedes elegir una foto del ticket o escribir el '
                            'gasto a mano.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                if (denied)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _askPermission,
                    icon: const Icon(CupertinoIcons.camera),
                    label: const Text('Permitir cámara'),
                  ),
                if (onPickPhoto != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: onPickPhoto,
                    icon: const Icon(CupertinoIcons.photo),
                    label: const Text('Elegir foto del ticket'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: .45),
      foregroundColor: Colors.white,
      fixedSize: const Size.square(44),
    ),
    icon: Icon(icon),
  );
}
