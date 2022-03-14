// Copyright 2020, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:slide_puzzle/src/app_state.dart';
import 'package:slide_puzzle/src/core/puzzle_animator.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'core/puzzle_proxy.dart';
import 'flutter.dart';
import 'shared_theme.dart';

const _accentBlue = Color(0xff000579);

class ThemeAr extends SharedTheme {
  @override
  String get name => 'Simple';

  const ThemeAr();

  @override
  Color get puzzleThemeBackground => Colors.white;

  @override
  Color get puzzleBackgroundColor => Colors.white70;

  @override
  Color get puzzleAccentColor => _accentBlue;

  @override
  RoundedRectangleBorder puzzleBorder(bool small) =>
      const RoundedRectangleBorder(
        side: BorderSide(color: Colors.black26, width: 1),
        borderRadius: BorderRadius.all(
          Radius.circular(4),
        ),
      );

  @override
  Widget tileButton(int i, PuzzleProxy puzzle, bool small) {
    if (i == puzzle.tileCount) {
      assert(puzzle.solved);
      return const Center(
        child: Icon(
          Icons.thumb_up,
          size: 72,
          color: _accentBlue,
        ),
      );
    }

    final correctPosition = puzzle.isCorrectPosition(i);

    final content = createInk(
      Center(
        child: Text(
          (i + 1).toString(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: correctPosition ? FontWeight.bold : FontWeight.normal,
            fontSize: small ? 30 : 49,
          ),
        ),
      ),
    );

    return createButton(
      puzzle,
      small,
      i,
      content,
      color: const Color.fromARGB(255, 13, 87, 155),
    );
  }

  Future<void> addNodes(AppState appState, bool small) async {
    final puzzle = appState.puzzle as PuzzleAnimator;
    // print(puzzle.planeHitMatrix);
    // final anchor = ARPlaneAnchor(transformation: puzzle.planeHitMatrix);
    // var newNode = puzzle.node(0);
    // var didAddAnchor = await appState.arAnchorManager.addAnchor(anchor);
    // var result =
    //     await appState.arObjectManager.addNode(newNode, planeAnchor: anchor);

    for (var i = 0; i < puzzle.tileCount; i++) {
      final node = puzzle.node(i);
      final anchor = puzzle.arPlaneAnchor(i);
      final didAddAnchor = await appState.arAnchorManager.addAnchor(anchor);

      if (didAddAnchor!) {
        final didAddNodeToAnchor =
            await appState.arObjectManager.addNode(node, planeAnchor: anchor);
        print(didAddNodeToAnchor);
        if (!didAddNodeToAnchor!) {
          appState.arSessionManager.onError('Failed to add node');
        }
      } else {
        appState.arSessionManager.onError('Failed to add anchor');
      }
    }
    print(puzzle.locations);
  }
}
