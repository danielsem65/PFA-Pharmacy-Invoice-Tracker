import 'package:flutter/material.dart';

import '../core/design.dart';
import 'glass.dart';

/// A dialog that is actually a pane of glass.
///
/// Flutter's own dialog is a flat rounded rectangle: it can be tinted, but the
/// page behind it can never show through, because a colour has no way to blur
/// what is under it. A dialog is the one surface in a desktop app that is
/// guaranteed to be floating over content, so it is the one place the glass
/// has to be real rather than implied.
///
/// The trick is to let [Dialog] keep doing everything it is good at — centring,
/// insets, getting out of the way of the keyboard, sizing itself to its
/// content — and replace only the part it cannot do, which is the material. The
/// dialog's own background is switched off and a [GlassSurface] is put behind
/// its content instead, so the [BackdropFilter] ends up between the page and
/// the text.
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
    builder: (context) {
      final media = MediaQuery.of(context);
      return Dialog(
        // The glass behind the content is the dialog's surface now.
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // The pane brings its own margin, so Dialog must not add a second one.
        insetPadding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
        child: Center(
          child: ConstrainedBox(
            // The same ceiling Dialog applies on its own, so a dialog never
            // grows past the window it is floating in. Wide enough for the
            // receipt viewer, which is the widest thing the app puts in one.
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: media.size.height - media.padding.vertical - 48,
            ),
            child: GlassSurface(
              level: GlassLevel.ultra,
              radius: 24,
              child: Theme(
                data: Theme.of(context).copyWith(
                  // An AlertDialog is the usual thing being shown here, and it
                  // is a Dialog itself. Left alone it would paint a second
                  // opaque rectangle on top of the very pane it is sitting in.
                  dialogTheme: const DialogThemeData(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    insetPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(),
                  ),
                  // A dialog is a glass pane, not a sheet of paper.
                  canvasColor: Colors.transparent,
                ),
                // Built under both the pane and the override, so the caller's
                // context sees the same ancestors it would see under a Dialog.
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      );
    },
  );
}
