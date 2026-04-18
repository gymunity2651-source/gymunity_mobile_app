import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 440);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuart;
  static const Curve exitCurve = Curves.easeInCubic;

  static const Offset revealOffset = Offset(0, 0.035);
  static const Offset routeOffset = Offset(0.035, 0.018);
  static const Offset tabEnterOffset = Offset(0.04, 0.02);
  static const Offset tabExitOffset = Offset(-0.03, -0.015);

  static const double pressedScale = 0.985;
}
