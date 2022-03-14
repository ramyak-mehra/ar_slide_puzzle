// Copyright 2020, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' show Point;

import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';

const zeroPoint = Point<double>(0, 0);

const _epsilon = 0.0001;

/// Represents a point object with a location and velocity.
class Body {
  Point<double> _velocity;
  Point<double> _location;
  ARNode _node;
  Point<double> get velocity => _velocity;

  Point<double> get location => _location;
  ARNode get node => _node;

  Body({
    Point<double> location = zeroPoint,
    Point<double> velocity = zeroPoint,
    required ARNode node,
  })  : assert(location.magnitude.isFinite),
        _location = location,
        assert(velocity.magnitude.isFinite),
        _velocity = velocity,
        _node = node;
  factory Body.raw(
    double x,
    double y,
    double vx,
    double vy,
    ARNode node,
  ) =>
      Body(
        location: Point(x, y),
        velocity: Point(vx, vy),
        node: node,
      );

  Body clone() => Body(
        location: _location,
        velocity: _velocity,
        node: _node,
      );

  /// Add the velocity specified in [delta] to `this`.
  void kick(Point<double> delta) {
    assert(delta.magnitude.isFinite);
    _velocity = delta;
  }

  /// [drag] must be greater than or equal to zero. It defines the percent of
  /// the previous velocity that is lost every second.

  bool animate(double seconds,
      {Point<double> force = zeroPoint,
      double drag = 0,
      double? maxVelocity,
      Point<double>? snapTo}) {
    assert(seconds.isFinite && seconds > 0,
        'milliseconds must be finite and > 0 (was $seconds)');

    assert(force.x.isFinite && force.y.isFinite, 'force must be finite');

    assert(drag.isFinite && drag >= 0, 'drag must be finiate and >= 0');

    maxVelocity ??= double.infinity;
    assert(maxVelocity > 0, 'maxVelocity must be null or > 0');

    final dragVelocity = _velocity * (1 - drag * seconds);

    if (_sameDirection(_velocity, dragVelocity)) {
      assert(dragVelocity.magnitude <= _velocity.magnitude,
          'Huh? $dragVelocity $_velocity');
      _velocity = dragVelocity;
    } else {
      _velocity = zeroPoint;
    }

    // apply force to velocity
    _velocity += force * seconds;

    // apply terminal velocity
    if (_velocity.magnitude > maxVelocity) {
      _velocity = _unitPoint(_velocity) * maxVelocity;
    }

    // update location
    final locationDelta = _velocity * seconds;
    if (locationDelta.magnitude > _epsilon ||
        (force.magnitude * seconds) > _epsilon) {
      _location += locationDelta;
      updateNodeLocation();
      return true;
    } else {
      if (snapTo != null && (_location.distanceTo(snapTo) < _epsilon * 2)) {
        _location = snapTo;
        updateNodeLocation();
      }
      _velocity = zeroPoint;
      return false;
    }
  }

  void updateNodeLocation() {
    node.position = node.position.clone()
      ..x = _location.x
      ..y = _location.y;
  }

  @override
  String toString() =>
      'Body name: ${_node.name} @(${_location.x},${_location.y}) ↕(${_velocity.x},${_velocity.y}) ,';

  @override
  bool operator ==(Object other) =>
      other is Body &&
      other._location == _location &&
      other._velocity == _velocity &&
      other._node == _node;

  // Since this is a mutable class, a constant value is returned for `hashCode`
  // This ensures values don't get lost in a Hashing data structure.
  // Note: this means you shouldn't use this type in most Map/Set impls.
  @override
  int get hashCode => 199;
}

Point<double> _unitPoint(Point<double> source) {
  final result = source * (1 / source.magnitude);
  return Point(result.x.isNaN ? 0 : result.x, result.y.isNaN ? 0 : result.y);
}

bool _sameDirection(Point a, Point b) {
  return a.x.sign == b.x.sign && a.y.sign == b.y.sign;
}
