import 'package:flutter/material.dart';

import 'glass.dart';

/// A dialog that is actually a pane of glass.
///
/// Flutter's own dialog is a flat rounded rectangle: it can be tinted, but the
/// page behind it can never show through, because a colour has no way to blur
/// what is under it. A dialog is the one surface in a desktop app that is
/// guaranteed to be floating over content, so it is the one place the glass
/// has to be real rather than implied — this builds the route by hand and puts
/// a [BackdropFilter] in the middle of it.
///
/// The arguments match [showDialog], so swapping one for the other changes
/// nothing a caller can observe. Dialogs built with [AlertDialog] keep their own
/// padding and layout: only the flat background is taken away from them, by a
/// [Theme] override scoped to the dialog's own subtree.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, __) {
      return _GlassDialogPane(
        child: Theme(
          data: Theme.of(context).copyWith(
            // The pane below is the dialog's surface. Left alone, AlertDialog
            // would paint an opaque rectangle on top of the very thing it is
            // floating on.
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(),
            ),
            // The same reason: a dialog is a glass pane, not a sheet of paper.
            canvasColor: Colors.transparent,
          ),
          // Built under both the pane and the override, so the caller's context
          // sees the same ancestors it would see under a Dialog.
          child: Builder(builder: builder),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          // Dropping in from slightly small and settling, the way a sheet of
          // glass lands on a desk. A straight fade reads as a web popup.
          scale: Tween<double>(begin: 0.955, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Centres and bounds a dialog the way [Dialog] would, then frosts it.
class _GlassDialogPane extends StatelessWidget {
  const _GlassDialogPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // The same ceiling Dialog applies, so a dialog never grows past
              // the window it is floating in. Wide enough for the receipt
              // viewer, which is the widest thing the app ever puts in one.
              maxWidth: 720,
              maxHeight: media.size.height - media.padding.vertical - 48,
            ),
            child: GlassSurface(
              level: GlassLevel.ultra,
              radius: 24,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
