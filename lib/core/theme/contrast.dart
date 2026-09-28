import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 contrast ratio between [a] and [b] (1.0 … 21.0).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// AA threshold for normal-size text.
const wcagAaNormalText = 4.5;
