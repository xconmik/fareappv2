import 'package:flutter/material.dart';

class FareLogo extends StatelessWidget {
  final double height;
  final double? width;

  const FareLogo({
    Key? key,
    this.height = 50,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/fare_logo.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
    );
  }
}
