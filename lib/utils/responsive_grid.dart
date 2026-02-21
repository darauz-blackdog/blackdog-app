import 'package:flutter/material.dart';

/// Returns responsive grid delegate that auto-calculates column count
/// based on the actual available width (works inside NavigationRail, etc).
///
/// [compact] mode targets smaller items (~100px wide) for home popular products.
/// Normal mode targets standard product cards (~170px wide) for catalog/search.
SliverGridDelegate responsiveProductGrid({bool compact = false}) {
  if (compact) {
    return const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 130,
      childAspectRatio: 0.82,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    );
  }

  return const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 200,
    childAspectRatio: 0.7,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  );
}
