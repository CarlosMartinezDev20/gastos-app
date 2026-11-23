import 'package:flutter/material.dart';

/// Shared rhythm for the movement, goal and history-filter forms.
class FormLayout {
  const FormLayout._();
  static const inset = 22.0;
  static const fieldGap = 16.0;
  static const sectionGap = 20.0;

  static TextStyle? titleStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineSmall
      ?.copyWith(fontWeight: FontWeight.w700, height: 1.15);
}

class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
