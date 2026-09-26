import 'package:flutter/material.dart';

import '../core/design.dart';
import 'glass.dart';

/// A dialog that is actually a pane of glass.
///
/// Flutter's own dialog is a flat rounded rectangle: it can be tinted, but the
/// page behind it can never show through, because a colour has no way to blur
/// what is under it. A dialog is the one surface in a desktop app that is
/// guaranteed to be floating over content, so it is the one place the glass has
/// to be real rather than implied.
///
/// [Dialog] keeps doing everything it is good at — its insets, its centring, its
/// habit of getting out of the way of the keyboard, and above all its habit of
/// sizing itself to whatever it is given. Only the material changes: the
/// dialog's own background is switched off in the theme, and a [GlassSurface]
/// is wrapped around its content, so the [BackdropFilter] ends up sitting
/// between the page and the words.
///
/// The arguments match [showDialog], so swapping one for the other changes
/// nothing a caller can observe.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    builder: (dialogContext) {
      return Theme(
        // Scoped to this dialog only, and read by both the Dialog below and the
        // AlertDialog the caller is about to return.
        data: Theme.of(dialogContext).copyWith(
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            // Exactly the margin a dialog had before, so nothing about how much
            // room the content gets has changed.
            insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            shape: RoundedRectangleBorder(),
          ),
          // A dialog is a glass pane, not a sheet of paper.
          canvasColor: Colors.transparent,
        ),
        child: Dialog(
          child: GlassSurface(
            level: GlassLevel.ultra,
            radius: 24,
            // The one bound worth adding: a ceiling on width, so the receipt
            // viewer and the wide forms cannot stretch a pane across a 4K
            // monitor. Height is left entirely to the content, as before.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // Built under the pane, so the caller's context sits below this
              // dialog in the tree, and the navigator it finds is the one this
              // dialog was pushed onto - the one whose top route is the dialog.
              child: Builder(builder: builder),
            ),
          ),
        ),
      );
    },
  );
}
