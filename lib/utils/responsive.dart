import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static const double _compactBreakpoint = 360;
  static const double _expandedBreakpoint = 600;
  static const double maxContentWidth = 700;
  static const double maxFormWidth = 500;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _compactBreakpoint;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _expandedBreakpoint;

  static double padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < _compactBreakpoint) return 16;
    if (w < _expandedBreakpoint) return 20;
    return 32;
  }

  static double paddingSmall(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < _compactBreakpoint) return 12;
    if (w < _expandedBreakpoint) return 16;
    return 24;
  }

  static int homeGridCols(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < _expandedBreakpoint) return 2;
    return 3;
  }

  static double imageHeight(BuildContext context, {double ratio = 0.4, double max = 400}) {
    final w = MediaQuery.sizeOf(context).width;
    final computed = w * ratio;
    return computed > max ? max : computed;
  }
}

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isExpanded(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
