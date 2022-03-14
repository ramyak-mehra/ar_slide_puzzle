// Copyright 2020, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';

abstract class PuzzleControls implements Listenable {
  void reset();

  int get clickCount;

  int get incorrectTiles;

  bool get autoPlay;

  bool get solved;

  ConfettiController get confettiController;

  void changeScale(double scale);

  void changeDistance(double distance);

  void puzzleEnd();

  void Function(bool? newValue)? get setAutoPlayFunction;
}
