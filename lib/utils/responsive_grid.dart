import 'package:flutter/material.dart';

/// Returns responsive grid delegate based on screen width.
///
/// [compact] mode targets smaller items (home popular products).
/// Normal mode targets standard product cards (catalog, search).
SliverGridDelegateWithFixedCrossAxisCount responsiveProductGrid(
  BuildContext context, {
  bool compact = false,
}) {
  final width = MediaQuery.sizeOf(context).width;

  final int crossAxisCount;
  final double spacing;
  final double aspectRatio;

  if (compact) {
    // Compact: more columns, smaller cards
    crossAxisCount = switch (width) {
      < 360 => 3,
      < 600 => 4,
      < 900 => 5,
      _ => 6,
    };
    spacing = 8;
    aspectRatio = 0.78;
  } else {
    // Full: standard product cards
    crossAxisCount = switch (width) {
      < 400 => 2,
      < 600 => 3,
      < 900 => 4,
      _ => 5,
    };
    spacing = 12;
    aspectRatio = 0.7;
  }

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    childAspectRatio: aspectRatio,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
  );
}
