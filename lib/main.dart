// Copyright 2020, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'src/core/puzzle_animator.dart';
import 'src/flutter.dart';
import 'src/puzzle_home_state.dart';

void main() => runApp(const PuzzleApp());

class PuzzleApp extends StatelessWidget {
  final int rows, columns;

  const PuzzleApp({this.columns = 3, this.rows = 3});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Slide Puzzle',
        home: _PuzzleHome(rows, columns),
        debugShowCheckedModeBanner: false,
      );
}

class _PuzzleHome extends StatefulWidget {
  final int _rows, _columns;

  const _PuzzleHome(this._rows, this._columns);

  @override
  PuzzleHomeState createState() =>
      PuzzleHomeState(PuzzleAnimator(_rows, _columns, 10, Matrix4.zero()));
}
