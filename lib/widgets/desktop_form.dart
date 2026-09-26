import 'package:flutter/material.dart';

/// Inserts a gap between items — used to build form sections without a Column
/// per row.
List<Widget> withGaps(List<Widget> items, double gap) {
  return [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      items[i],
    ],
  ];
}

typedef FieldSpec = ({Widget child, int flex});

/// Holds a form to a comfortable reading width and centres it in whatever space
/// the window gives it, so a short form is not stretched edge to edge on a wide
/// screen.
///
/// The [Align] is what makes this work: a scroll view hands its children a
/// tight width, so a bare [ConstrainedBox] inside one is silently ignored.
class ReadingWidth extends StatelessWidget {
  const ReadingWidth({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A row of form fields that keeps its column layout on a desktop window and
/// collapses to a single stacked column when the available width is too small.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.fields,
    this.spacing = 12,
    this.breakpoint = 640,
  });

  final List<FieldSpec> fields;
  final double spacing;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (fields.length > 1 && constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(flex: fields[i].flex, child: fields[i].child),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: withGaps([for (final f in fields) f.child], spacing),
        );
      },
    );
  }
}

/// A bordered, titled panel — the building block of the desktop form pages.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: texts.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...withGaps(children, 12),
        ],
      ),
    );
  }
}

/// A tinted note under a form section — says what the fields do rather than
/// repeating what they are called.
class FormHint extends StatelessWidget {
  const FormHint({super.key, required this.text, this.icon = Icons.lightbulb_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned action bar so Save is always reachable without scrolling a long form.
class FormActionsBar extends StatelessWidget {
  const FormActionsBar({
    super.key,
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
    this.leading,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              if (leading != null) Expanded(child: leading!),
              if (leading != null) const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('cancel-form'),
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('save-form'),
                onPressed: onSave,
                icon: const Icon(Icons.check, size: 18),
                label: Text(saveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
