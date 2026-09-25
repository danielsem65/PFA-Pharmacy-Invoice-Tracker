import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final bool compact;

  static final List<Color> primary = [
    const Color(0xFF0E7490),
    const Color(0xFF0F9D77),
  ];

  static final List<Color> danger = [
    const Color(0xFFD44545),
    const Color(0xFFF07A55),
  ];

  static final List<Color> neutral = [
    const Color(0xFF34495E),
    const Color(0xFF5D6D7E),
  ];

  @override
  Widget build(BuildContext context) {
    final width = compact ? 88.0 : 120.0;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.95)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 18 : 22,
                ),
          ),
        ],
      ),
    );
  }
}