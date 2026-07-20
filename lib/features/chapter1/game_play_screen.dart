// lib/features/chapter1/game_play_screen.dart

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart';
import 'package:emotional_bakery/core/widgets/dialogue_overlay.dart';
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';

class GamePlayScreen extends StatefulWidget {
  final bool isPrologue;
  const GamePlayScreen({super.key, this.isPrologue = false});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with TickerProviderStateMixin {
  final BakeryGame _game = BakeryGame();

  bool _isDialogueActive = false;
  int _dialogueStep = 0;
  List<String> _dialogueTexts = [];
  String? _interactionText;
  bool _isSettingOpen = false;

  // 채온이 상태 변수
  String _chaeonState = 'idle';
  bool _isChaeonFacingRight = true; // 채온 좌우 반전용 스위치

  // 릴리안 상태 및 자동 걷기 애니메이션 변수
  late AnimationController _lillianController;
  double _lillianStartX = 1500.0; // 릴리안 시작 좌표
  double _lillianTargetX = 900.0; // 걸어와서 멈출 좌표
  bool _isLillianWalking = false; // 릴리안이 현재 걷는 중인지 여부
  bool _isLillianVisible = false; // 릴리안이 화면에 등장했는지 여부

  // 릴리안 두 번째 등장(계단을 올라와 채온이 앞까지 걸어옴)
  late AnimationController _lillianStairsController;
  Animation<Offset>? _lillianStairsAnimation;
  bool _isLillianSecondEntranceActive = false;

  // 왼쪽 끝에서 튜토리얼 화면으로 전환 중 중복 네비게이션 방지 플래그
  bool _isNavigatingToTutorial = false;

  // 릴리안/채온 "깜짝 놀람" 모션(살짝 위로 껑충)용 컨트롤러 및 오프셋 애니메이션
  late AnimationController _lillianHopController;
  late Animation<double> _lillianHopOffset;
  late AnimationController _chaeonHopController;
  late Animation<double> _chaeonHopOffset;

  // 암전 시작시, true 고정. 이때부터 온도계/뒤로가기 노출, 이동 버튼 숨김
  bool _isGuidePhaseStarted = false;
  // 첫 만남 대사 종료 후, 채온이가 1200 지점에 도착하면 true. 이때부터 방향키 숨김, 이동 잠금
  bool _isFreeWalkPhase = false;

  // 채온-릴리안 첫 만남 대사(line/choice 그래프 순회, 타이핑 효과, 온도 변화) 상태 관리
  late final SceneDialogueController _sceneController;

  bool _thermometerImagesPrecached = false;

  @override
  void initState() {
    super.initState();

    _sceneController = SceneDialogueController(
      onDialogueEnd: () {
        // 릴리안-채온 대화가 끝났으니 이제부터 자유롭게 걸을 수 있는 구간으로 전환하고 릴리안 퇴장
        setState(() {
          _isFreeWalkPhase = true;
          _isLillianVisible = false;
        });
        // 카메라가 채온이를 따라가도록 복귀
        _game.lillianArrivalX = null;
        _game.startCameraCatchUp();
      },
      onLillianHop: () => _lillianHopController.forward(from: 0),
      onChaeonHop: () => _chaeonHopController.forward(from: 0),
    );
    _sceneController.addListener(_onSceneControllerChanged);

    // 릴리안 걷기 애니메이션 제어기 설정
    _lillianController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            setState(() {}); // 애니메이션 프레임마다 화면을 다시 그려 릴리안 이동 반영
          });

    // 릴리안 계단 등장 애니메이션 제어기 설정
    _lillianStairsController = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      });
    _lillianStairsController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isLillianWalking = false); // 도착하면 idle 모션으로 전환
      }
    });

    // 릴리안/채온 깜짝 놀람 모션: 짧게 위로 튀었다가 제자리로 돌아옴
    _lillianHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _lillianHopOffset = _buildHopOffset(_lillianHopController);

    _chaeonHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _chaeonHopOffset = _buildHopOffset(_chaeonHopController);

    // 릴리안 도착 시 실행될 리스너
    _lillianController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isLillianWalking = false;
          _game.isMovementBlocked = false;
        });
        // 릴리안 도착 후 첫 만남 대사 시작
        print("릴리안 도착 완료 조작 잠금 해제");
        _sceneController.startFirstMeetDialogue();
      }
    });

    _game.onShowDialogue = (textLines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isDialogueActive = true;
            _isGuidePhaseStarted = true;
            _dialogueStep = 0;
            _dialogueTexts = textLines;
          });
        }
      });
    };

    // 릴리안이 계단을 다 올라와서 채온이 앞까지 걸어오면, 그 다음 연출을 트리거
    _game.onReachPostSceneEnd = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isFreeWalkPhase = false;
            _chaeonState = 'idle';
          });
          _triggerLillianStairsEntrance();
        }
      });
    };

    // 배경 오브젝트 클릭 시 정보성 팝업 텍스트 표시
    _game.onInteract = (text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _interactionText = text);
      });
    };

    _game.onGameUpdate = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    };

    // 왼쪽 끝까지 간 뒤 계속 왼쪽으로 가려 하면 마을 배경으로 전환
    _game.onReachLeftEdge = () {
      if (widget.isPrologue || _isNavigatingToTutorial) return;
      _isNavigatingToTutorial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          fadeThroughBlackRoute(
            const TutorialScreen(
              initialStep: 2,
              initialPlayerX: 1500,
              initialFacingLeft: true,
            ),
          ),
        );
        if (mounted) {
          setState(() => _isNavigatingToTutorial = false);
        }
      });
    };
  }

  void _onSceneControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_thermometerImagesPrecached) {
      _thermometerImagesPrecached = true;
      for (int i = 1; i <= 10; i++) {
        precacheImage(
          AssetImage('assets/images/main_thermometer_$i.png'),
          context,
        );
      }
      for (int i = 1; i <= widgets.dialogueBoxWidths.length; i++) {
        precacheImage(
          AssetImage('assets/images/main_dialogue_box_$i.png'),
          context,
        );
      }
    }
  }

  @override
  void dispose() {
    _sceneController.removeListener(_onSceneControllerChanged);
    _sceneController.dispose();
    _lillianController.dispose(); // 메모리 누수 방지용
    _lillianStairsController.dispose();
    _lillianHopController.dispose();
    _chaeonHopController.dispose();
    super.dispose();
  }

  // 짧게 위로 튀었다가 바운스감 있게 제자리로 돌아오는 오프셋 애니메이션 생성
  Animation<double> _buildHopOffset(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -20.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -20.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 55,
      ),
    ]).animate(controller)..addListener(() {
      setState(() {}); // 모션 프레임마다 화면을 다시 그려 오프셋 반영
    });
  }

  void _triggerLillianWalk() {
    setState(() {
      _isDialogueActive = false; // 대화창 끄기
      _isLillianVisible = true; // 대화가 끝났으니 이제부터 릴리안 등장
      _isLillianWalking = true; // 릴리안 걷기 상태 돌입

      // 채온이는 항상 x=650에서 멈추므로, 릴리안의 도착 좌표도 고정값 사용
      _lillianTargetX = 900.0;

      // 이 시점부터 카메라가 채온이 대신 "채온이-릴리안 도착 지점"의 중간을 따라가도록 설정
      _game.lillianArrivalX = _lillianTargetX;
    });

    // 릴리안 걷는 속도를 채온이 이동 속도(Chaeon.speed)와 동일하게 맞춤
    double distance = (_lillianTargetX - _lillianStartX).abs();
    double chaeonSpeed = _game.chaeon?.speed ?? 250.0 * 0.85;
    int durationMs = (distance / chaeonSpeed * 1000).round().clamp(1, 60000);
    _lillianController.duration = Duration(milliseconds: durationMs);

    _lillianController.forward(from: 0.0);
  }

  // 릴리안이 계단을 올라와서 채온이 앞까지 걸어오는 연출 트리거
  void _triggerLillianStairsEntrance() {
    const Offset stairsStart = Offset(1800, 180);
    // 릴리안이 계단을 다 올라와서 채온이 앞까지 걸어오면, 그 다음 연출을 트리거
    const Offset stairsTop = Offset(1632, 163);
    final double chaeonX = _game.chaeon?.position.x ?? 1300.0;
    final Offset walkEnd = Offset(chaeonX + 280, 163); // 채온이 앞 280 거리

    final double climbDist = (stairsTop - stairsStart).distance;
    final double walkDist = (walkEnd - stairsTop).distance;

    _lillianStairsAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: stairsStart, end: stairsTop),
        weight: climbDist,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: stairsTop, end: walkEnd),
        weight: walkDist,
      ),
    ]).animate(_lillianStairsController);

    // 릴리안 걷는 속도를 채온이 이동 속도와 동일하게 맞춤
    double chaeonSpeed = _game.chaeon?.speed ?? 250.0 * 0.85;
    int durationMs = ((climbDist + walkDist) / chaeonSpeed * 1000)
        .round()
        .clamp(1, 60000);
    _lillianStairsController.duration = Duration(milliseconds: durationMs);

    // 첫 만남 등장 때와 같은 방식: 카메라가 채온이와 릴리안 도착 예정 지점의 중간을 추적
    _game.lillianArrivalX = walkEnd.dx;

    setState(() {
      _isLillianSecondEntranceActive = true;
      _isLillianVisible = true;
      _isLillianWalking = true;
    });

    _lillianStairsController.forward(from: 0);
  }

  void _advanceDialogue() {
    setState(() {
      if (_dialogueStep < _dialogueTexts.length - 1) {
        _dialogueStep++;
      } else {
        // 대화창이 모두 끝나면 릴리안 걸어오기
        _triggerLillianWalk();
      }
    });
  }

  // 뒤로가기 버튼: 대화창이 켜져 있으면 대화창을 닫고, 아니면 선택지 이전 line으로 돌아감
  void _handleBackButtonTap() {
    if (_isDialogueActive && _dialogueStep != 0) {
      _advanceDialogue();
      return;
    }
    _sceneController.goBackScene();
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // 오브젝트 클릭 정보 팝업은 이동 가능한 상태에서만 허용
    _game.canInteract =
        !widget.isPrologue && (!_isGuidePhaseStarted || _isFreeWalkPhase);

    // 실시간 카메라 스크롤 값 계산
    double cameraX = _game.camera.isMounted
        ? _game.camera.viewfinder.position.x
        : 0.0;

    // 배경이 세로로 항상 꽉 차도록 하는 카메라 줌
    double zoom = h / _game.mapHeight;

    // 채온이 렌더링 좌표 계산
    double chaeonX = (_game.chaeon != null && _game.chaeon!.isMounted)
        ? _game.chaeon!.position.x
        : 0.0;

    double chaeonDisplaySize = 172 * zoom;
    double renderChaeonX = (chaeonX - cameraX) * zoom - chaeonDisplaySize / 2;

    // 릴리안 렌더링 좌표 계산
    double currentLillianX;
    double lillianTopValue;
    if (_isLillianSecondEntranceActive && _lillianStairsAnimation != null) {
      final Offset pos = _lillianStairsAnimation!.value;
      currentLillianX = pos.dx;
      lillianTopValue = rH(pos.dy);
    } else {
      currentLillianX = Tween<double>(
        begin: _lillianStartX,
        end: _lillianTargetX,
      ).evaluate(_lillianController);
      lillianTopValue = rH(163);
    }
    // 채온이랑 똑같이 중심 기준 보정 필요 (안 하면 릴리안이 오른쪽으로 밀려 그려짐)
    double lillianDisplaySize = 174 * zoom;
    double renderLillianX =
        (currentLillianX - cameraX) * zoom - lillianDisplaySize / 2;

    // 채온-릴리안 말풍선 가로 위치 계산용: 각 캐릭터의 화면상 가로 중심
    double chaeonCenterX = renderChaeonX + chaeonDisplaySize / 2;
    double lillianCenterX = renderLillianX + lillianDisplaySize / 2;

    final DialogueGraph? sceneDialogue = _sceneController.sceneDialogue;
    final String? sceneNodeId = _sceneController.sceneNodeId;
    final DialogueNode? currentSceneNode =
        (sceneDialogue != null && sceneNodeId != null)
        ? sceneDialogue.nodes[sceneNodeId]
        : null;
    final DialogueNode? lastLineNode = _sceneController.lastLineNode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 게임 엔진 구역
            Positioned.fill(
              key: const ValueKey('game'),
              child: GameWidget(
                game: _game,
                overlayBuilderMap: {
                  'dialogue': (BuildContext context, BakeryGame game) {
                    return DialogueOverlay(game: game);
                  },
                },
                initialActiveOverlays: widget.isPrologue
                    ? const ['dialogue']
                    : const [],
              ),
            ),

            // 2층: 채온 GIF
            if (!widget.isPrologue &&
                _game.chaeon != null &&
                _game.chaeon!.isMounted)
              Positioned(
                key: const ValueKey('chaeon'),
                left: renderChaeonX,
                bottom: rH(50), // 튜토리얼 채온이와 동일한 바닥선 기준
                child: Transform.translate(
                  offset: Offset(0, _chaeonHopOffset.value),
                  child: Transform.flip(
                    flipX: !_isChaeonFacingRight,
                    child: Image.asset(
                      _chaeonState == 'walk'
                          ? 'assets/images/chaeon_walk_right.gif'
                          : 'assets/images/chaeon_idle_right.gif',
                      width: chaeonDisplaySize,
                      height: chaeonDisplaySize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

            // 3층: 릴리안 GIF
            if (_isLillianVisible)
              Positioned(
                key: const ValueKey('lillian'),
                left: renderLillianX,
                top: lillianTopValue, // 튜토리얼 채온이와 동일한 바닥선 기준
                height: lillianDisplaySize,
                child: Transform.translate(
                  offset: Offset(0, _lillianHopOffset.value),
                  child: Transform.flip(
                    flipX: _isLillianWalking,
                    child: Image.asset(
                      _isLillianWalking
                          ? 'assets/images/lillian_walk.gif'
                          : 'assets/images/lillian_idle.gif',
                      width: lillianDisplaySize,
                      height: lillianDisplaySize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

            // 4층: 온도계
            if (_isGuidePhaseStarted &&
                !(_isDialogueActive && _dialogueStep == 0))
              widgets.buildThermometer(
                key: 'thermometer_below',
                rW: rW,
                rH: rH,
                temperature: _sceneController.temperature,
                temperatureChangeText: _sceneController.temperatureChangeText,
              ),

            // 4-3층: 뒤로가기 버튼 (가이드 대사 0번째 스텝 전용).
            // 7층 암전보다 아래라서 검은 반투명에 덮여 흐릿하게 보임
            if (_isDialogueActive && _dialogueStep == 0)
              widgets.buildBackButton(
                key: 'back_below_guide',
                rW: rW,
                rH: rH,
                onTap: _handleBackButtonTap,
              ),

            // 4-4층: 설정 버튼 (가이드 대사 0/1 스텝 전용).
            // 7층 암전보다 아래라서 검은 반투명 배경에 덮여 흐릿하게 보임
            if (_isGuidePhaseStarted && _isDialogueActive)
              widgets.buildSettingButton(
                key: 'setting_dimmed',
                rW: rW,
                rH: rH,
                onTap: () => setState(() => _isSettingOpen = true),
              ),

            // 5층: 가상 패드 왼쪽 이동 버튼 영역
            if (!widget.isPrologue &&
                (!_isGuidePhaseStarted || _isFreeWalkPhase))
              Positioned(
                key: const ValueKey('dpad_left'),
                left: rW(686),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_left.png',
                  onTapDown: () {
                    _game.movePlayer(-1);
                    setState(() {
                      _chaeonState = 'walk';
                      _isChaeonFacingRight = false;
                    });
                  },
                  onTapUp: () {
                    _game.movePlayer(0);
                    setState(() => _chaeonState = 'idle');
                  },
                  onTapCancel: () {
                    _game.movePlayer(0);
                    // 대화 트리거로 버튼이 같은 프레임에 사라지면 위젯 트리 잠긴 상태서 호출될 수 있어 다음 프레임으로 미룸
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _chaeonState = 'idle');
                    });
                  },
                  rW: rW,
                  rH: rH,
                ),
              ),

            // 6층: 가상 패드 오른쪽 이동 버튼 영역
            if (!widget.isPrologue &&
                (!_isGuidePhaseStarted || _isFreeWalkPhase))
              Positioned(
                key: const ValueKey('dpad_right'),
                left: rW(778),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_right.png',
                  onTapDown: () {
                    _game.movePlayer(1);
                    setState(() {
                      _chaeonState = 'walk';
                      _isChaeonFacingRight = true;
                    });
                  },
                  onTapUp: () {
                    _game.movePlayer(0);
                    setState(() => _chaeonState = 'idle');
                  },
                  onTapCancel: () {
                    _game.movePlayer(0);
                    // 대화 트리거로 버튼이 같은 프레임에 사라지면 위젯 트리 잠긴 상태서 호출될 수 있어 다음 프레임으로 미룸
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _chaeonState = 'idle');
                    });
                  },
                  rW: rW,
                  rH: rH,
                ),
              ),

            // 7층: 화면 어둡게 덮는 반투명 암전 레이어
            if (_isDialogueActive)
              Positioned.fill(
                key: const ValueKey('darken'),
                child: IgnorePointer(
                  ignoring: false,
                  child: GestureDetector(
                    onTap: _advanceDialogue,
                    child: Container(color: Colors.black.withOpacity(0.55)),
                  ),
                ),
              ),

            // 8층: 온도계
            if (_isDialogueActive && _dialogueStep == 0)
              widgets.buildThermometer(
                key: 'thermometer_above',
                rW: rW,
                rH: rH,
                temperature: _sceneController.temperature,
                temperatureChangeText: _sceneController.temperatureChangeText,
              ),

            // 8-2층: 뒤로가기 버튼
            // 아직 클릭 기능 없어서 탭하면 아래 암전 레이어가 받아서 대사 넘어감 (설정 버튼은 계속 4-2층에만 있음)
            if (_isDialogueActive && _dialogueStep != 0)
              widgets.buildBackButton(
                key: 'back_above',
                rW: rW,
                rH: rH,
                onTap: _handleBackButtonTap,
              ),

            // 9층: x=650 지점 가이드 대사창
            if (_isDialogueActive && _dialogueTexts.isNotEmpty)
              widgets.buildCustomDialogue(
                key: 'dialogue_box',
                step: _dialogueStep,
                rW: rW,
                rH: rH,
              ),

            // 10층: 오브젝트 클릭 정보성 팝업 - 화면 아무 곳이나 탭하면 닫힘
            if (_interactionText != null)
              Positioned.fill(
                key: const ValueKey('interaction_dismiss'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _interactionText = null),
                ),
              ),

            // 11층: 오브젝트 클릭 정보성 팝업 텍스트창
            if (_interactionText != null)
              widgets.buildInteractionBox(
                text: _interactionText!,
                rW: rW,
                rH: rH,
              ),

            // 12층: 채온-릴리안 첫 만남 말풍선 대화 (line 노드)
            if (currentSceneNode != null && currentSceneNode.type == 'line')
              Positioned.fill(
                key: const ValueKey('scene_bubble_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sceneController.advanceScene,
                  child: Stack(
                    children: [
                      widgets.buildSceneBubble(
                        node: currentSceneNode,
                        rW: rW,
                        rH: rH,
                        chaeonCenterX: chaeonCenterX,
                        lillianCenterX: lillianCenterX,
                        typedCharCount: _sceneController.typedCharCount,
                      ),
                    ],
                  ),
                ),
              ),

            // 13층: 채온-릴리안 첫 만남 선택지 (choice 노드)
            if (currentSceneNode != null && currentSceneNode.type == 'choice')
              Positioned.fill(
                key: const ValueKey('scene_choice_layer'),
                child: Stack(
                  children: [
                    if (lastLineNode != null)
                      widgets.buildSceneBubble(
                        node: lastLineNode,
                        rW: rW,
                        rH: rH,
                        chaeonCenterX: chaeonCenterX,
                        lillianCenterX: lillianCenterX,
                        typedCharCount: _sceneController.typedCharCount,
                        charCount: lastLineNode.spans.fold<int>(
                          0,
                          (sum, s) => sum + s.text.length,
                        ),
                      ),
                    widgets.buildSceneChoices(
                      node: currentSceneNode,
                      rW: rW,
                      rH: rH,
                      onChooseOption: _sceneController.chooseSceneOption,
                    ),
                  ],
                ),
              ),

            // 14층: 뒤로가기 버튼 (가이드 대사/선택지 중엔 4-3층 흐릿한 버튼이 대신 나오므로 여기선 안 그림)
            if (_isGuidePhaseStarted && !_isDialogueActive)
              widgets.buildBackButton(
                key: 'back_below',
                rW: rW,
                rH: rH,
                onTap: _handleBackButtonTap,
              ),

            // 15층: 선택지 되돌리기 불가 안내 배지. 선택지를 한 번이라도 골랐는데 히스토리가 비어서 더 못 돌아갈 때만 띄움
            if (_sceneController.choiceLockedMessage != null)
              Positioned(
                key: const ValueKey('choice_locked_badge'),
                left: rW(636),
                top: rH(74),
                child: widgets.buildBlackRoundedBadge(
                  _sceneController.choiceLockedMessage!,
                  rW: rW,
                  rH: rH,
                ),
              ),

            // 16층: 설정(옵션) 버튼. 15층 안내 배지보다 위에 있어야 배지가 버튼에 안 가려짐
            if (_isGuidePhaseStarted && !_isDialogueActive)
              widgets.buildSettingButton(
                key: 'setting',
                rW: rW,
                rH: rH,
                onTap: () => setState(() => _isSettingOpen = true),
              ),

            // 17층: 설정 팝업. 16층 설정 버튼보다 위에 있어야 팝업이 버튼에 가려지지 않음
            if (_isSettingOpen)
              Builder(
                builder: (context) {
                  double popupW = w * 0.8;
                  double popupH = h * 0.8;

                  // 이미지 원본 비율 650x343 기준으로 레터박스 맞춰서 중앙에 배치
                  const double imageAspect = 650 / 343;
                  double renderedW, renderedH;
                  if (imageAspect > popupW / popupH) {
                    renderedW = popupW;
                    renderedH = popupW / imageAspect;
                  } else {
                    renderedH = popupH;
                    renderedW = popupH * imageAspect;
                  }
                  double offsetX = (popupW - renderedW) / 2;
                  double offsetY = (popupH - renderedH) / 2;

                  return Positioned.fill(
                    key: const ValueKey('setting_popup'),
                    child: GestureDetector(
                      // 배경 탭 흡수해서 뒤 설정 버튼 안 눌리게 막음 (팝업은 안 닫힘)
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: SizedBox(
                            width: popupW,
                            height: popupH,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: offsetX,
                                  top: offsetY,
                                  width: renderedW,
                                  height: renderedH,
                                  child: Image.asset(
                                    'assets/images/main_setting_ex.png',
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                // 이미지에 그려진 X 닫기 버튼 위치에 맞춘 히트박스 (원본 650x343 비율 그대로, 레터박스 오프셋 더함)
                                Positioned(
                                  right: offsetX + renderedW * (5 / 650),
                                  top: offsetY + renderedH * (5 / 343),
                                  width: renderedW * (45 / 650),
                                  height: renderedH * (45 / 343),
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _isSettingOpen = false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
