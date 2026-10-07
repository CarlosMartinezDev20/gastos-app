import 'dart:convert';

/// What a widget on Inicio shows.
enum HomeWidgetType {
  balance(
    'Balance',
    'Tu dinero disponible, con Michi y sus consejos.',
    sizes: [HomeWidgetSize.wide],
    styles: [
      HomeWidgetStyle.card,
      HomeWidgetStyle.ink,
      HomeWidgetStyle.aurora,
      HomeWidgetStyle.lilac,
      HomeWidgetStyle.mint,
    ],
  ),
  income('Ingresos', 'Lo que entró en los últimos 30 días.'),
  spending('Gastos', 'Lo que salió en los últimos 30 días.'),
  cashflow(
    'Flujo del mes',
    'Ingresos contra gastos y lo que te queda.',
    sizes: [HomeWidgetSize.wide],
  ),
  week(
    'Esta semana',
    'Tu gasto de cada uno de los últimos 7 días.',
    sizes: [HomeWidgetSize.compact, HomeWidgetSize.wide],
  ),
  goals(
    'Metas',
    'Cuánto te falta para tus metas de ahorro.',
    sizes: [HomeWidgetSize.compact, HomeWidgetSize.wide],
  ),
  budgets(
    'Presupuestos',
    'Cuánto llevas gastado de tus límites del mes.',
    sizes: [HomeWidgetSize.compact, HomeWidgetSize.wide],
  ),
  recent(
    'Actividad reciente',
    'Tus últimos movimientos.',
    sizes: [HomeWidgetSize.wide],
    styles: [HomeWidgetStyle.card],
  ),
  quickAdd(
    'Atajos',
    'Registra un gasto o un ingreso con un toque.',
    sizes: [HomeWidgetSize.compact, HomeWidgetSize.wide],
  );

  const HomeWidgetType(
    this.label,
    this.description, {
    this.sizes = const [HomeWidgetSize.compact],
    this.styles = HomeWidgetStyle.values,
  });

  final String label;
  final String description;

  /// Sizes the widget can take; the first is the default.
  final List<HomeWidgetSize> sizes;
  final List<HomeWidgetStyle> styles;
}

/// A compact widget takes half a row (two side by side); a wide one, the
/// whole row.
enum HomeWidgetSize {
  compact('Pequeño'),
  wide('Grande');

  const HomeWidgetSize(this.label);

  final String label;
}

/// Colors of a widget, from the app palette.
enum HomeWidgetStyle {
  card('Básico'),
  ink('Negro'),
  accent('Lima'),
  mint('Menta'),
  blush('Rosa'),
  lilac('Lila'),
  aurora('Aurora');

  const HomeWidgetStyle(this.label);

  final String label;
}

class HomeWidgetConfig {
  const HomeWidgetConfig(this.type, this.size, this.style);

  /// The type's default size, with [style] or the type's default colors.
  factory HomeWidgetConfig.of(HomeWidgetType type, [HomeWidgetStyle? style]) =>
      HomeWidgetConfig(type, type.sizes.first, style ?? defaultStyle(type));

  final HomeWidgetType type;
  final HomeWidgetSize size;
  final HomeWidgetStyle style;

  bool get compact => size == HomeWidgetSize.compact;

  HomeWidgetConfig copyWith({HomeWidgetSize? size, HomeWidgetStyle? style}) =>
      HomeWidgetConfig(type, size ?? this.size, style ?? this.style);

  Map<String, String> toJson() => {
    'type': type.name,
    'size': size.name,
    'style': style.name,
  };

  /// Null when the entry is not valid (e.g. saved by a newer version).
  static HomeWidgetConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = HomeWidgetType.values.asNameMap()[json['type']];
    if (type == null) return null;
    final size = HomeWidgetSize.values.asNameMap()[json['size']];
    final style = HomeWidgetStyle.values.asNameMap()[json['style']];
    return HomeWidgetConfig(
      type,
      type.sizes.contains(size) ? size! : type.sizes.first,
      type.styles.contains(style) ? style! : defaultStyle(type),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetConfig &&
      other.type == type &&
      other.size == size &&
      other.style == style;

  @override
  int get hashCode => Object.hash(type, size, style);
}

HomeWidgetStyle defaultStyle(HomeWidgetType type) => switch (type) {
  HomeWidgetType.income => HomeWidgetStyle.accent,
  HomeWidgetType.spending => HomeWidgetStyle.ink,
  HomeWidgetType.week => HomeWidgetStyle.lilac,
  HomeWidgetType.budgets => HomeWidgetStyle.blush,
  HomeWidgetType.goals => HomeWidgetStyle.mint,
  HomeWidgetType.quickAdd => HomeWidgetStyle.ink,
  _ => HomeWidgetStyle.card,
};

/// The Inicio of a new user: what the screen showed before it was
/// customizable.
final defaultHomeLayout = [
  HomeWidgetConfig.of(HomeWidgetType.balance),
  HomeWidgetConfig.of(HomeWidgetType.income),
  HomeWidgetConfig.of(HomeWidgetType.spending),
  HomeWidgetConfig.of(HomeWidgetType.recent),
  HomeWidgetConfig.of(HomeWidgetType.goals).copyWith(size: HomeWidgetSize.wide),
];

/// SharedPreferences key of a user's layout (each account has its own).
String homeLayoutKey(String userId) => 'home_layout_$userId';

String encodeHomeLayout(List<HomeWidgetConfig> layout) =>
    jsonEncode([for (final c in layout) c.toJson()]);

/// The saved layout, or null when there is none or it can't be read.
/// Invalid entries and repeated types are dropped.
List<HomeWidgetConfig>? decodeHomeLayout(String? raw) {
  if (raw == null) return null;
  final Object? json;
  try {
    json = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (json is! List) return null;
  final seen = <HomeWidgetType>{};
  return [
    for (final entry in json)
      if (HomeWidgetConfig.fromJson(entry) case final c? when seen.add(c.type))
        c,
  ];
}

/// Groups the layout into blocks that are laid out as units: a wide widget,
/// or up to two consecutive compact widgets that share a row.
List<List<HomeWidgetConfig>> homeBlocks(List<HomeWidgetConfig> layout) {
  final blocks = <List<HomeWidgetConfig>>[];
  for (final config in layout) {
    final last = blocks.lastOrNull;
    if (config.compact &&
        last != null &&
        last.length == 1 &&
        last.single.compact) {
      last.add(config);
    } else {
      blocks.add([config]);
    }
  }
  return blocks;
}

/// Index of the goal to feature: the unfinished one closest to its target,
/// else the first. Null when there are no goals.
int? featuredGoalIndex(List<({double saved, double target})> goals) {
  int? best;
  var bestProgress = -1.0;
  for (final (i, g) in goals.indexed) {
    if (g.target <= 0 || g.saved >= g.target) continue;
    final progress = g.saved / g.target;
    if (progress > bestProgress) {
      best = i;
      bestProgress = progress;
    }
  }
  return best ?? (goals.isEmpty ? null : 0);
}
