import 'package:flutter/material.dart';

/// Protects user-requested exits. A successful save uses Navigator.pop directly.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.controllers,
    required this.hasChanges,
    required this.saving,
    required this.child,
    this.onDiscard,
  });

  final List<TextEditingController> controllers;
  final bool Function() hasChanges;
  final bool saving;
  final Widget child;
  final Future<void> Function()? onDiscard;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _asking = false;

  Future<void> _confirmExit() async {
    if (_asking || widget.saving) return;
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text('Lo que escribiste todavía no se ha guardado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    _asking = false;
    if (mounted && discard == true && !widget.saving) {
      try {
        await widget.onDiscard?.call();
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo descartar el borrador. Intenta de nuevo.',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(widget.controllers),
    builder: (context, child) => PopScope<void>(
      canPop: !widget.saving && !widget.hasChanges(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: child!,
    ),
    child: widget.child,
  );
}
