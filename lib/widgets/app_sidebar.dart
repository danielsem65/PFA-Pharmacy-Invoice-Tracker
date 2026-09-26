import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

/// The left rail: where you are, and the two or three things you do most.
///
/// It can fold down to a strip of icons for the times the numbers need the
/// room, and it carries the window's quick actions so the common jobs never
/// need a trip through a menu.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.index,
    required this.onSelect,
    this.collapsed = false,
    this.onToggleCollapsed,
    this.onShowShortcuts,
    this.version = '',
  });

  final int index;
  final ValueChanged<int> onSelect;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;
  final VoidCallback? onShowShortcuts;
  final String version;

  static const double expandedWidth = 244;
  static const double collapsedWidth = 78;

  /// The shell's branches, in order. An item's position is the branch it
  /// opens, so the two lists must stay the same length.
  static const int itemCount = 5;

  static const _items = <_NavItemData>[
    _NavItemData(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: 'Overview',
      accent: Aurora.indigo,
    ),
    _NavItemData(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Invoices',
      accent: Aurora.teal,
    ),
    _NavItemData(
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping,
      label: 'Suppliers',
      accent: Aurora.sky,
    ),
    _NavItemData(
      icon: Icons.medication_outlined,
      selectedIcon: Icons.medication_liquid,
      label: 'Products',
      accent: Aurora.violet,
    ),
    _NavItemData(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Payments',
      accent: Aurora.emerald,
    ),
  ];

  double get width => collapsed ? collapsedWidth : expandedWidth;

  @override
  Widget build(BuildContext context) {
    assert(
      _items.length == itemCount,
      'The sidebar and the shell must list the same destinations, in order.',
    );
    return Container(
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Aurora.nightC, Aurora.nightA, Aurora.nightB],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Two soft blooms so the panel is not a flat block of navy.
          Positioned(
            top: -90,
            right: -70,
            child: const _SidebarBloom(color: Aurora.indigo, size: 260),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: const _SidebarBloom(color: Aurora.teal, size: 240),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: collapsed ? 10 : 18,
                  ),
                  child: collapsed
                      ? const Center(child: _BrandMark())
                      : const _Brand(),
                ),
                SizedBox(height: collapsed ? 18 : 20),
                if (!collapsed)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _SectionLabel('WORKSPACE'),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
                    child: Divider(color: Color(0x22FFFFFF), height: 1),
                  ),
                for (var i = 0; i < _items.length; i++)
                  _SidebarItem(
                    data: _items[i],
                    selected: index == i,
                    collapsed: collapsed,
                    onTap: () => onSelect(i),
                  ),
                const SizedBox(height: 18),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: collapsed ? 10 : 18,
                  ),
                  child: collapsed
                      ? _QuickAddCollapsed()
                      : const _QuickAdd(),
                ),
                if (!collapsed) ...<Widget>[
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: _QuickRow(),
                  ),
                ],
                const Spacer(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    collapsed ? 10 : 18,
                    0,
                    collapsed ? 10 : 18,
                    14,
                  ),
                  child: collapsed
                      ? _CollapsedFooter(
                          onShowShortcuts: onShowShortcuts,
                          onToggleCollapsed: onToggleCollapsed,
                        )
                      : _SidebarFooter(
                          version: version,
                          onShowShortcuts: onShowShortcuts,
                          onToggleCollapsed: onToggleCollapsed,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color accent;
}

class _SidebarBloom extends StatelessWidget {
  const _SidebarBloom({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Aurora.teal, Aurora.indigo],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Aurora.teal.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.medication_liquid, color: Colors.white, size: 23),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const _BrandMark(),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Invoice Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'PFA Pharmacy',
                style: TextStyle(
                  color: Aurora.teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Aurora.teal, Aurora.indigo],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Aurora.indigo.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Fills the whole gradient bar, so there is no dead space at the edges.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/new'),
          child: const SizedBox(
            height: 44,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'New invoice',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAddCollapsed extends StatelessWidget {
  const _QuickAddCollapsed();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New invoice',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/new'),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Aurora.teal, Aurora.indigo],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// The three other things worth making in one click, as icons rather than more
/// words down the rail.
class _QuickRow extends StatelessWidget {
  const _QuickRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _QuickAction(
          icon: Icons.local_shipping_outlined,
          label: 'New supplier',
          onTap: () => context.go('/suppliers/new'),
        ),
        const SizedBox(width: 8),
        _QuickAction(
          icon: Icons.medication_outlined,
          label: 'New product',
          onTap: () => context.go('/products/new'),
        ),
        const SizedBox(width: 8),
        _QuickAction(
          icon: Icons.payments_outlined,
          label: 'Record payment',
          onTap: () => context.go('/payments/new'),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Icon(icon, size: 18, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.version,
    this.onShowShortcuts,
    this.onToggleCollapsed,
  });

  final String version;
  final VoidCallback? onShowShortcuts;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.cloud_off_outlined,
            size: 15,
            color: Aurora.emerald,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (version.isNotEmpty)
                  Text(
                    'v$version',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _FooterIcon(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: () => context.go('/settings'),
          ),
          _FooterIcon(
            icon: Icons.keyboard_alt_outlined,
            tooltip: 'Keyboard shortcuts',
            onTap: onShowShortcuts,
          ),
          _FooterIcon(
            icon: Icons.keyboard_double_arrow_left_rounded,
            tooltip: 'Collapse sidebar',
            onTap: onToggleCollapsed,
          ),
        ],
      ),
    );
  }
}

class _CollapsedFooter extends StatelessWidget {
  const _CollapsedFooter({this.onShowShortcuts, this.onToggleCollapsed});

  final VoidCallback? onShowShortcuts;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _FooterIcon(
          icon: Icons.tune_rounded,
          tooltip: 'Settings',
          onTap: () => context.go('/settings'),
          boxed: true,
        ),
        const SizedBox(height: 8),
        _FooterIcon(
          icon: Icons.keyboard_alt_outlined,
          tooltip: 'Keyboard shortcuts',
          onTap: onShowShortcuts,
          boxed: true,
        ),
        const SizedBox(height: 8),
        _FooterIcon(
          icon: Icons.keyboard_double_arrow_right_rounded,
          tooltip: 'Expand sidebar',
          onTap: onToggleCollapsed,
          boxed: true,
        ),
      ],
    );
  }
}

class _FooterIcon extends StatelessWidget {
  const _FooterIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.boxed = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: boxed
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                )
              : null,
          child: Icon(icon, size: 15, color: Colors.white54),
        ),
      ),
    );
    return Tooltip(message: tooltip, child: button);
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.data,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final accent = widget.data.accent;
    final collapsed = widget.collapsed;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.13)
                : Colors.white.withValues(alpha: _hovered ? 0.07 : 0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          // The whole pill answers the click, not just the word inside it.
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: Colors.white.withValues(alpha: 0.06),
              child: collapsed
                  ? Tooltip(
                      message: widget.data.label,
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Icon(
                            selected
                                ? widget.data.selectedIcon
                                : widget.data.icon,
                            size: 20,
                            color: selected
                                ? accent
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: <Widget>[
                          // The accent bar grows out of the side of the page
                          // you are on.
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            width: 3,
                            height: selected ? 22 : 0,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: selected ? 11 : 0,
                          ),
                          AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            scale: selected ? 1.12 : 1,
                            child: Icon(
                              selected
                                  ? widget.data.selectedIcon
                                  : widget.data.icon,
                              size: 20,
                              color: selected
                                  ? accent
                                  : Colors.white
                                      .withValues(alpha: _hovered ? 0.85 : 0.6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.data.label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.72),
                                fontSize: 14,
                                fontWeight:
                                    selected ? FontWeight.w800 : FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: accent.withValues(alpha: 0.9),
                            ),
                        ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
