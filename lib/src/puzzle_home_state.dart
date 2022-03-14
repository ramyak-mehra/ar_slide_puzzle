// Copyright 2020, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:slide_puzzle/src/value_tab_controller.dart';
import 'app_state.dart';
import 'core/puzzle_animator.dart';
import 'core/puzzle_proxy.dart';
import 'flutter.dart';
import 'puzzle_controls.dart';
import 'shared_theme.dart';
import 'themes.dart';

class _PuzzleConfig extends ChangeNotifier {
  double scale = 0.2;
  double distance = 0.0;
  bool started = false;
  final PuzzleControls puzzleControls;
  _PuzzleConfig(this.puzzleControls);

  void end() {
    started = false;
    notifyListeners();
  }

  void updateScale(double scale) {
    this.scale = scale;
    print('updateScale: ${this.scale}');
    puzzleControls.changeScale(scale);
    notifyListeners();
  }

  void updateDistance(double distance) {
    this.distance = distance;
    puzzleControls.changeDistance(distance);
    notifyListeners();
  }

  void updateStarted() {
    started = !started;
    notifyListeners();
  }
}

class _PuzzleControls extends ChangeNotifier implements PuzzleControls {
  final PuzzleHomeState _parent;

  _PuzzleControls(this._parent);

  @override
  bool get autoPlay => _parent._autoPlay;

  void _notify() => notifyListeners();

  @override
  void Function(bool? newValue)? get setAutoPlayFunction {
    if (_parent.puzzle.solved) {
      return null;
    }
    return _parent._setAutoPlay;
  }

  @override
  int get clickCount => _parent.puzzle.clickCount;

  @override
  int get incorrectTiles => _parent.puzzle.incorrectTiles;

  @override
  void reset() => _parent.puzzle.reset();

  @override
  void changeScale(double scale) => _parent.puzzle.changeScale(scale);
  @override
  void changeDistance(double distance) =>
      _parent.puzzle.changeDistance(distance);

  @override
  bool get solved => _parent.puzzle.solved;

  @override
  void puzzleEnd() async {
    assert(_parent._puzzleConfigListenable.started);
    assert(_parent.puzzle.solved);
    _parent._confettiController.play();
    await _parent._audioPlayer.play('winsound.mp3');
    await Future.delayed(const Duration(seconds: 5));
    await _parent.puzzle.removeNodes(_parent);
    _parent._puzzleConfigListenable.end();
    reset();
  }

  @override
  ConfettiController get confettiController => _parent._confettiController;
}

class PuzzleHomeState extends State
    with SingleTickerProviderStateMixin, AppState {
  @override
  final PuzzleAnimator puzzle;

  @override
  final _AnimationNotifier animationNotifier = _AnimationNotifier();

  late ConfettiController _confettiController;

  // bool started = false;
  Duration _tickerTimeSinceLastEvent = Duration.zero;
  late Ticker _ticker;
  late Duration _lastElapsed;
  late StreamSubscription _puzzleEventSubscription;

  bool _autoPlay = false;
  late _PuzzleControls _autoPlayListenable;

  late _PuzzleConfig _puzzleConfigListenable;
  late AudioCache _audioPlayer;
  @override
  late final ARObjectManager arObjectManager;
  @override
  late final ARAnchorManager arAnchorManager;
  @override
  late final ARSessionManager arSessionManager;
  @override
  late final ARViewCreatedCallback onARViewCreated;

  PuzzleHomeState(this.puzzle) {
    _puzzleEventSubscription = puzzle.onEvent.listen(_onPuzzleEvent);
  }

  void startPuzzle(ARHitTestResult hitTestResult) async {
    assert(!_puzzleConfigListenable.started);
    await puzzle.generateAnchors(
        hitTestResult.distance, hitTestResult.worldTransform);
    await puzzle.addNodes(this);

    _ticker = createTicker(_onTick);
    _lastElapsed = Duration.zero;
    _ensureTicking();
    _puzzleConfigListenable.updateStarted();
  }

  void _setAutoPlay(bool? newValue) {
    if (newValue != _autoPlay) {
      setState(() {
        // Only allow enabling autoPlay if the puzzle is not solved
        _autoPlayListenable._notify();
        _autoPlay = newValue! && !puzzle.solved;
        if (_autoPlay) {
          _ensureTicking();
        }
      });
      // show
    }
  }

  @override
  void initState() {
    _autoPlayListenable = _PuzzleControls(this);
    _puzzleConfigListenable = _PuzzleConfig(_autoPlayListenable);
    onARViewCreated = arCreate;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));
    _audioPlayer = AudioCache();
    super.initState();
  }

  void arCreate(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager.onInitialize(
          showFeaturePoints: false,
          showPlanes: true,
          showWorldOrigin: false,
          handleTaps: true,
          handlePans: true,
          handleRotation: true,
        );
    this.arObjectManager.onInitialize();
    this.arSessionManager.onError('errorMessage');
    this.arSessionManager.onPlaneOrPointTap =
        (!_puzzleConfigListenable.started ? onPlaneOrPointTapped : null)!;
    this.arObjectManager.onNodeTap = onNodeTap;
  }

  void onNodeTap(List<String> nodeNames) {
    for (final nodeName in nodeNames) {
      puzzle.clickOrShake(int.parse(nodeName) - 1);
    }
  }

  Future<void> onPlaneOrPointTapped(
      List<ARHitTestResult> hitTestResults) async {
    if (!_puzzleConfigListenable.started) {
      final singleHitTestResult = hitTestResults.firstWhere(
          (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane);
      startPuzzle(singleHitTestResult);
    } else {
      print('already started');
    }
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider<AppState>.value(value: this),
          ListenableProvider<PuzzleControls>.value(
            value: _autoPlayListenable,
          ),
          ListenableProvider<_PuzzleConfig>.value(
            value: _puzzleConfigListenable,
          ),
        ],
        child: const Material(child: LayoutBuilder(builder: _doBuild)),
      );

  @override
  void dispose() {
    animationNotifier.dispose();
    _ticker.dispose();
    _autoPlayListenable.dispose();
    _puzzleEventSubscription.cancel();
    arSessionManager.dispose();
    _puzzleConfigListenable.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onPuzzleEvent(PuzzleEvent e) {
    _autoPlayListenable._notify();
    if (e != PuzzleEvent.random) {
      _setAutoPlay(false);
    }
    _tickerTimeSinceLastEvent = Duration.zero;

    _ensureTicking();
    setState(() {
      // noop
    });
  }

  void _ensureTicking() {
    if (!_ticker.isTicking) {
      _ticker.start();
      setState(() {});
    }
  }

  void _onTick(Duration elapsed) {
    if (elapsed == Duration.zero) {
      _lastElapsed = elapsed;
    }
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;

    if (delta.inMilliseconds <= 0) {
      // `_delta` may be negative or zero if `elapsed` is zero (first tick)
      // or during a restart. Just ignore this case.
      return;
    }

    _tickerTimeSinceLastEvent += delta;
    puzzle.update(delta > _maxFrameDuration ? _maxFrameDuration : delta);

    if (!puzzle.stable) {
      animationNotifier.animate();
    } else {
      if (!_autoPlay) {
        _ticker.stop();
        _lastElapsed = Duration.zero;
      }
    }

    if (_autoPlay &&
        _tickerTimeSinceLastEvent > const Duration(milliseconds: 200)) {
      puzzle.playRandom();

      if (puzzle.solved) {
        _setAutoPlay(false);
      }
    }
  }
}

class _AnimationNotifier extends ChangeNotifier {
  void animate() {
    notifyListeners();
  }
}

const _maxFrameDuration = Duration(milliseconds: 34);

Widget _updateConstraints(
    BoxConstraints constraints, Widget Function(bool small) builder) {
  const _smallWidth = 580;

  final constraintWidth =
      constraints.hasBoundedWidth ? constraints.maxWidth : 1000.0;

  final constraintHeight =
      constraints.hasBoundedHeight ? constraints.maxHeight : 1000.0;

  return builder(constraintWidth < _smallWidth || constraintHeight < 690);
}

Widget _doBuild(BuildContext _, BoxConstraints constraints) =>
    _updateConstraints(constraints, _doBuildCore);

Widget _doBuildCore(bool small) => ValueTabController<SharedTheme>(
      values: themes,
      child: Consumer<SharedTheme>(
        builder: (_, theme, __) => AnimatedContainer(
          duration: puzzleAnimationDuration,
          child: Center(
            child: theme.styledWrapper(
              small,
              Stack(
                children: [
                  Consumer<AppState>(
                    builder: (context, appState, _) => ARView(
                      onARViewCreated: appState.onARViewCreated,
                      planeDetectionConfig:
                          PlaneDetectionConfig.horizontalAndVertical,
                    ),
                  ),
                  Consumer<_PuzzleConfig>(builder: (context, puzzleConfig, _) {
                    if (!puzzleConfig.started) {
                      return Center(
                        child: Container(
                          child: Text(
                            'Tap anywhere on the ground to start',
                            style: TextStyle(
                              color: Colors.grey.shade50,
                              fontSize: 30,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      // height: 60,
                      child:
                          Consumer<PuzzleControls>(builder: (_, controls, __) {
                        if (controls.solved) {
                          controls.puzzleEnd();
                          return Center(
                            child: ConfettiWidget(
                                createParticlePath: drawStar,
                                blastDirectionality:
                                    BlastDirectionality.explosive,
                                // shouldLoop: true,
                                confettiController:
                                    controls.confettiController),
                          );
                        }

                        return Card(
                            margin: const EdgeInsets.only(
                                left: 10, bottom: 6, right: 10),
                            child: ExpansionTile(
                              title: Row(children: [
                                Tooltip(
                                  message: 'Reset',
                                  child: IconButton(
                                    onPressed: controls.reset,
                                    icon: Icon(Icons.refresh,
                                        color: puzzleAccentColor),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Auto play',
                                  child: Checkbox(
                                    value: controls.autoPlay,
                                    onChanged: controls.setAutoPlayFunction,
                                    activeColor: puzzleAccentColor,
                                  ),
                                ),
                                const Spacer(),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: controls.clickCount.toString(),
                                        style: _infoStyle,
                                      ),
                                      TextSpan(
                                          text: ' Moves', style: _infoStyle),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: RichText(
                                    textAlign: TextAlign.right,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: controls.incorrectTiles
                                              .toString(),
                                          style: _infoStyle,
                                        ),
                                        TextSpan(
                                            text: ' Ducks left',
                                            style: _infoStyle),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                )
                              ]),
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Consumer<_PuzzleConfig>(
                                      builder: (context, puzzleConfig, _) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Change Distance ',
                                          style: _infoStyle,
                                        ),
                                        Slider(
                                            min: -1,
                                            max: 1,
                                            label: 'Change distance',
                                            value: puzzleConfig.distance,
                                            onChanged: (value) {
                                              puzzleConfig
                                                  .updateDistance(value);
                                            }),
                                      ],
                                    );
                                  }),
                                )
                              ],
                            ));
                      }),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );

const _accentBlue = Color(0xff000579);
Color get puzzleAccentColor => _accentBlue;

TextStyle get _infoStyle => TextStyle(
      color: puzzleAccentColor,
      fontWeight: FontWeight.bold,
    );
Path drawStar(Size size) {
  // Method to convert degree to radians
  double degToRad(double deg) => deg * (pi / 180.0);

  const numberOfPoints = 5;
  final halfWidth = size.width / 2;
  final externalRadius = halfWidth;
  final internalRadius = halfWidth / 2.5;
  final degreesPerStep = degToRad(360 / numberOfPoints);
  final halfDegreesPerStep = degreesPerStep / 2;
  final path = Path();
  final fullAngle = degToRad(360);
  path.moveTo(size.width, halfWidth);

  for (double step = 0; step < fullAngle; step += degreesPerStep) {
    path.lineTo(halfWidth + externalRadius * cos(step),
        halfWidth + externalRadius * sin(step));
    path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * sin(step + halfDegreesPerStep));
  }
  path.close();
  return path;
}
