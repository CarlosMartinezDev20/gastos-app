import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../providers/finance_providers.dart';

/// A floating pill while the screens show saved data because the API can't
/// be reached. Slides in over the content (transform only, no reflow).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(apiClientProvider).offline;
    final palette = context.palette;
    return ValueListenableBuilder<bool>(
      valueListenable: offline,
      builder: (context, isOffline, _) => IgnorePointer(
        ignoring: !isOffline,
        child: AnimatedSlide(
          offset: isOffline ? Offset.zero : const Offset(0, -1.5),
          duration: Motion.of(context, Motion.medium),
          curve: isOffline ? Motion.standard : Motion.exit,
          child: AnimatedOpacity(
            opacity: isOffline ? 1 : 0,
            duration: Motion.of(context, Motion.medium),
            child: Center(
              child: Material(
                color: palette.ink,
                shape: const StadiumBorder(),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.wifi_slash,
                        size: 16,
                        color: palette.onInk,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Sin conexión · lo último guardado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.onInk,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: palette.accent,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => refreshFinance(ref),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
