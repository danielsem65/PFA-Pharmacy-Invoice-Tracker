import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/theme.dart';

/// The window's own title bar, drawn by the app instead of Windows.
///
/// It sits above the sidebar and the page, is safe to drag by, and carries the
/// three window buttons. The dark block on the left is painted the same night
/// gradient as the sidebar so the two read as one piece of chrome.
///
/// Named for the app rather than for the package: window_manager ships a
/// caption of its own, and this one is built to match the sidebar.
class AppWindowCaption extends StatefulWidget {
  const AppWindowCaption({
    super.key,
    required this.sidebarWidth,
    required this.caption,
  });

  /// Whether this platform gets the app's own title bar.
  ///
  /// A widget test has no window behind it and reports a phone platform, so the
  /// caption is left out entirely there: the pages are then measured at the
  /// full height, and no test has to reason about a channel with nothing
  /// behind it.
  static bool get isSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// Matches the sidebar so the two line up down the left edge.
  final double sidebarWidth;
  final String caption;

  @override
  State<AppWindowCaption> createState() => _AppWindowCaptionState();
}

class _AppWindowCaptionState extends State<AppWindowCaption>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  /// The window manager is a platform channel, so it has nothing to say in a
  /// test. Ask anyway, and shrug if there is no answer.
  Future<void> _readMaximized() async {
    try {
      final value = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = value);
    } catch (_) {
      // No window to ask about.
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Nothing to act on.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: <Widget>[
          Container(
            width: widget.sidebarWidth,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Aurora.nightC, Aurora.nightA],
              ),
            ),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 18),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: <Color>[Aurora.teal, Aurora.sky],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'PFA Pharmacy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onDoubleTap: () => _guard(() async {
                if (_maximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              }),
              child: DragToMoveArea(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.03),
                  alignment: Alignment.center,
                  child: Text(
                    widget.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _CaptionButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimise',
            onPressed: () => _guard(windowManager.minimize),
          ),
          _CaptionButton(
            icon: _maximized
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded,
            tooltip: _maximized ? 'Restore' : 'Maximise',
            onPressed: () => _guard(() async {
              if (_maximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            }),
          ),
          _CaptionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            danger: true,
            onPressed: () => _guard(windowManager.close),
          ),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: 38,
            child: HoverTint(
              color: danger
                  ? const Color(0xFFE11D48)
                  : Colors.white.withValues(alpha: 0.10),
              child: Icon(
                icon,
                size: danger ? 16 : 15,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a colour behind its child while the pointer is over it. The window
/// buttons live on a painted background, so they cannot use a Material splash.
class HoverTint extends StatefulWidget {
  const HoverTint({
    super.key,
    required this.child,
    required this.color,
    this.radius = 0,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  State<HoverTint> createState() => _HoverTintState();
}

class _HoverTintState extends State<HoverTint> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? widget.color : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: widget.child,
      ),
    );
  }
}
