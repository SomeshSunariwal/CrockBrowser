import 'package:flutter/material.dart';

/// Single source of branding; callers choose layout size, never a replacement icon.
class CrockLogo extends StatelessWidget {
  const CrockLogo({super.key, this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Crock Browser logo',
    image: true,
    child: Image.asset(
      'assets/branding/crock_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    ),
  );
}
