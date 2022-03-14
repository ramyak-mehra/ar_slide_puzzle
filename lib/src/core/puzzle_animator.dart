// Copyright 2020, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' show Point, Random;

import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:slide_puzzle/src/app_state.dart';
import 'package:slide_puzzle/src/puzzle_home_state.dart';
import 'package:vector_math/vector_math_64.dart';
import 'body.dart';
import 'puzzle.dart';
import 'puzzle_proxy.dart';

class PuzzleAnimator implements PuzzleProxy {
  final _rnd = Random();
  List<Body> _locations;
  List<ARPlaneAnchor> _arPlaneAnchors;
  final _controller = StreamController<PuzzleEvent>();
  bool _nextRandomVertical = true;
  Puzzle _puzzle;
  int _clickCount = 0;
  Matrix4 _planeHitMatrix;
  double _zValue;
  Matrix4 get planeHitMatrix => _planeHitMatrix;
  List<Body> get locations => _locations;
  static const String baseUrl = 'http://192.168.1.9:8000/';
  bool _stable = true;

  bool get stable => _stable;

  List<ARPlaneAnchor> get arPlaneAnchors => _arPlaneAnchors;

  @override
  bool get solved => _puzzle.incorrectTiles == 0;

  @override
  int get width => _puzzle.width;

  @override
  int get height => _puzzle.height;

  @override
  int get length => _puzzle.length;

  @override
  int get tileCount => _puzzle.tileCount;

  int get incorrectTiles => _puzzle.incorrectTiles;

  int get clickCount => _clickCount;

  void reset() => _resetCore();

  Stream<PuzzleEvent> get onEvent => _controller.stream;

  @override
  bool isCorrectPosition(int value) => _puzzle.isCorrectPosition(value);

  @override
  Point<double> location(int index) => _locations[index].location;

  ARNode node(int index) => _locations[index].node;
  ARPlaneAnchor arPlaneAnchor(int index) => _arPlaneAnchors[index];

  int? _lastBadClick;
  int _badClickCount = 0;

  PuzzleAnimator(int width, int height, double zvalue, Matrix4 planeHitMatrix)
      : this._(Puzzle(width, height), zvalue, planeHitMatrix, []);

  PuzzleAnimator._(
      this._puzzle, this._zValue, this._planeHitMatrix, this._arPlaneAnchors)
      : _locations = List.generate(_puzzle.length, (i) {
          final name = i + 1;
          final newNode = ARNode(
              name: '$name',
              type: NodeType.webGLB,
              uri: '${baseUrl}duck_$name.glb',
              scale: Vector3(0.2, 0.2, 0.2),
              position: Vector3(0, 0, 0),
              rotation: Vector4(0.0, 1.0, 0.0, -89.9));

          return Body.raw((_puzzle.width - 1.0) / 2, (_puzzle.height - 1.0) / 2,
              0, 0, newNode);
        });

  Future<void> generateAnchors(double zValue, Matrix4 planeHitMatrix) async {
    _planeHitMatrix = planeHitMatrix;
    _arPlaneAnchors = [];
    _locations = List.generate(_puzzle.length, (i) {
      final position = Vector3(
          (_puzzle.width - 1.0) / 2, (_puzzle.height - 1.0) / 2, _zValue);
      final transformation = _planeHitMatrix.clone();
      // transformation.setEntry(0, 3, position.x);
      // transformation.setEntry(1, 3, position.y);
      // transformation.setEntry(2, 3, position.z);
      final arPlaneAnchor = ARPlaneAnchor(transformation: transformation);
      _arPlaneAnchors.add(arPlaneAnchor);
      final name = i + 1;
      final newNode = ARNode(
          type: NodeType.webGLB,
          name: '$name',
          uri: '${baseUrl}duck_$name.glb',
          scale: Vector3(0.2, 0.2, 0.2),
          position: Vector3(0, 0, 0),
          rotation: Vector4(0.0, 1.0, 0.0, -89.9));

      return Body.raw(
          (_puzzle.width - 1.0) / 2, (_puzzle.height - 1.0) / 2, 0, 0, newNode);
    });
  }

  void playRandom() {
    if (_puzzle.fitness == 0) {
      return;
    }
    _puzzle = _puzzle.clickRandom(vertical: _nextRandomVertical)!;
    _nextRandomVertical = !_nextRandomVertical;
    _clickCount++;
    _controller.add(PuzzleEvent.random);
  }

  @override
  void clickOrShake(int tileValue) {
    if (solved) {
      _controller.add(PuzzleEvent.noop);
      _shake(tileValue);
      _lastBadClick = null;
      _badClickCount = 0;
      return;
    }

    _controller.add(PuzzleEvent.click);
    if (!_clickValue(tileValue)) {
      _shake(tileValue);

      // This is logic to allow a user to skip to the end – useful for testing
      // click on 5 un-movable tiles in a row, but not the same tile twice
      // in a row
      if (tileValue != _lastBadClick) {
        _badClickCount++;
        if (_badClickCount >= 4) {
          // Do the reset!
          final newValues = List.generate(_puzzle.length, (i) {
            if (i == _puzzle.tileCount) {
              return _puzzle.tileCount - 1;
            } else if (i == (_puzzle.tileCount - 1)) {
              return _puzzle.tileCount;
            }
            return i;
          });
          _resetCore(source: newValues);
          _clickCount = 999;
        }
      } else {
        _badClickCount = 0;
      }
      _lastBadClick = tileValue;
    } else {
      _lastBadClick = null;
      _badClickCount = 0;
    }
  }

  void _resetCore({List<int>? source}) {
    _puzzle = _puzzle.reset(source: source);
    _clickCount = 0;
    _lastBadClick = null;
    _badClickCount = 0;
    _controller.add(PuzzleEvent.reset);
  }

  bool _clickValue(int value) {
    final newPuzzle = _puzzle.clickValue(value);
    if (newPuzzle == null) {
      return false;
    } else {
      _clickCount++;
      _puzzle = newPuzzle;
      return true;
    }
  }

  void _shake(int tileValue) {
    Point<double> deltaDouble;
    if (solved) {
      deltaDouble = Point(_rnd.nextDouble() - 0.5, _rnd.nextDouble() - 0.5);
    } else {
      final delta = _puzzle.openPosition() - _puzzle.coordinatesOf(tileValue);
      deltaDouble = Point(delta.x.toDouble(), delta.y.toDouble());
    }
    deltaDouble *= 0.5 / deltaDouble.magnitude;

    _locations[tileValue].kick(deltaDouble);
  }

  void update(Duration timeDelta) {
    assert(!timeDelta.isNegative);
    assert(timeDelta != Duration.zero);

    var animationSeconds = timeDelta.inMilliseconds / 60.0;
    if (animationSeconds == 0) {
      animationSeconds = 0.1;
    }
    assert(animationSeconds > 0);

    _stable = true;
    for (var i = 0; i < _puzzle.length; i++) {
      final target = _target(i);
      final body = _locations[i];

      _stable = !body.animate(animationSeconds,
              force: target - body.location,
              drag: .9,
              maxVelocity: 1.0,
              snapTo: target) &&
          _stable;
    }
  }

  Point<double> _target(int item) {
    final target = _puzzle.coordinatesOf(item);
    return Point(target.x.toDouble(), target.y.toDouble());
  }

  Future<void> addNodes(
    PuzzleHomeState homeState,
  ) async {
    final puzzle = this;

    for (var i = 0; i < puzzle.tileCount; i++) {
      final node = puzzle.node(i);
      final anchor = puzzle.arPlaneAnchor(i);
      final didAddAnchor = await homeState.arAnchorManager.addAnchor(anchor);

      if (didAddAnchor!) {
        final didAddNodeToAnchor =
            await homeState.arObjectManager.addNode(node, planeAnchor: anchor);
        print(didAddNodeToAnchor);
        if (!didAddNodeToAnchor!) {
          homeState.arSessionManager.onError('Failed to add node');
        }
      } else {
        homeState.arSessionManager.onError('Failed to add anchor');
      }
    }
  }

  Future<void> removeNodes(
    PuzzleHomeState homeState,
  ) async {
    final puzzle = this;

    for (var i = 0; i < puzzle.tileCount; i++) {
      final node = puzzle.node(i);
      final anchor = puzzle.arPlaneAnchor(i);
      homeState.arAnchorManager.removeAnchor(anchor);
      homeState.arObjectManager.removeNode(node);
    }
  }

  void changeScale(double scale) {
    for (var body in _locations) {
      body.node.scale = Vector3(scale, scale, scale);
    }
  }

  void changeDistance(double distance) {
    for (var body in _locations) {
      final position = body.node.position.clone();
      position.setValues(position.x, position.y, distance);

      body.node.position = position;
    }
  }
}
