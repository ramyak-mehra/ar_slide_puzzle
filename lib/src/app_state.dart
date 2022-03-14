// Copyright 2020, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:flutter/foundation.dart';

import 'core/puzzle_proxy.dart';

abstract class AppState {
  PuzzleProxy get puzzle;
  Listenable get animationNotifier;
  ARAnchorManager get arAnchorManager;
  ARObjectManager get arObjectManager;
  ARSessionManager get arSessionManager;
  ARViewCreatedCallback get onARViewCreated;
  // bool get started;
}
