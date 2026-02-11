import 'package:flutter/material.dart';

class Responsive {
  final Size size;
  final double width;
  final double height;
  final double scale;
  final double grid;

  const Responsive._({
    required this.size,
    required this.width,
    required this.height,
    required this.scale,
    required this.grid,
  });

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = (size.width / 375).clamp(0.85, 1.25);
    return Responsive._(
      size: size,
      width: size.width,
      height: size.height,
      scale: scale,
      grid: 8.0 * scale,
    );
  }

  double space(double value) => value * scale;
  double font(double value) => value * scale;
  double radius(double value) => value * scale;
  double icon(double value) => value * scale;
}
