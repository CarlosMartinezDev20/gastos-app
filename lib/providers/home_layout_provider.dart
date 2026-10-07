import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/home_layout.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

/// The widgets on Inicio, in order. Saved per user in SharedPreferences.
final homeLayoutProvider =
    NotifierProvider<HomeLayoutController, List<HomeWidgetConfig>>(
      HomeLayoutController.new,
    );

class HomeLayoutController extends Notifier<List<HomeWidgetConfig>> {
  String? _userId;

  @override
  List<HomeWidgetConfig> build() {
    _userId = ref.watch(currentUserIdProvider);
    final userId = _userId;
    if (userId == null) return defaultHomeLayout;
    return decodeHomeLayout(
          ref.read(sharedPreferencesProvider).getString(homeLayoutKey(userId)),
        ) ??
        defaultHomeLayout;
  }

  void _save(List<HomeWidgetConfig> layout) {
    state = layout;
    if (_userId case final userId?) {
      ref
          .read(sharedPreferencesProvider)
          .setString(homeLayoutKey(userId), encodeHomeLayout(layout));
    }
  }

  void add(HomeWidgetType type) {
    if (state.any((c) => c.type == type)) return;
    _save([...state, HomeWidgetConfig.of(type)]);
  }

  void remove(HomeWidgetType type) =>
      _save([...state.where((c) => c.type != type)]);

  /// Changes the size or colors of the widget of [type], from its current
  /// state (two quick edits don't undo each other).
  void edit(
    HomeWidgetType type, {
    HomeWidgetSize? size,
    HomeWidgetStyle? style,
  }) => _save([
    for (final c in state)
      c.type == type ? c.copyWith(size: size, style: style) : c,
  ]);

  /// Moves the widget at [oldIndex] so it ends up at [newIndex].
  void reorder(int oldIndex, int newIndex) {
    final layout = [...state];
    layout.insert(newIndex, layout.removeAt(oldIndex));
    _save(layout);
  }

  void reset() => _save(defaultHomeLayout);
}
