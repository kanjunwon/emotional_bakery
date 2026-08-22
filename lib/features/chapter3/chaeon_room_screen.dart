// lib/features/chapter3/chaeon_room_screen.dart
//
// 챕터3 시작 지점. 채온이 방에서 혼잣말 대사 하나 보여주고, 끝나면 dpad로
// 문까지 걸어가서 나갈 수 있게 함. kitchen_screen.dart 구조(레터박스 스케일,
// SceneDialogueController + buildSceneBubble 재사용) 그대로 따라감

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/models/interaction_model.dart';
import 'package:emotional_bakery/core/services/interaction_loader.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';

// room_bg.png 실측 좌표 기준 (874x456 캔버스)
// 채온이가 방 안에 서있는 위치
const double kChaeonRoomX = 240;
const double kChaeonRoomTopY = 210;

// 채온이가 좌우로 움직일 수 있는 범위. 정확한 값은 나중에 화면 보면서 조정 필요
const double kChaeonRoomMinX = 60;
const double kChaeonRoomMaxX = 700;
// 채온이 이동 속도(px/초). 다른 화면들이랑 동일하게 맞춤
const double kChaeonRoomSpeed = 225;
const Duration _moveTickInterval = Duration(milliseconds: 40);

// 문 클릭 영역. 임시 위치, 실제 화면 보면서 조정 필요
const double kRoomDoorX = 750;
const double kRoomDoorTopY = 60;
const double kRoomDoorWidth = 80;
const double kRoomDoorHeight = 250;

// 문 근접 판정 범위. 채온이가 이 범위 안에 있을 때만 문 탭이 실제로 이동시킴.
// tutorial_screen.dart의 빵집 문 isNearDoor 체크랑 동일한 패턴. 임시 값, 문 위치 확정되면 같이 조정 필요
const double kRoomDoorNearMinX = 620;
const double kRoomDoorNearMaxX = 700;
// 캐릭터 크기 보정 배수. worldScale이 456 기준으로 계산되는데, 빵집(game_play_screen.dart)의
// zoom은 402 기준(h/402)이라 같은 "172"를 써도 이 화면 쪽이 더 작게 렌더링됨.
// kitchen_screen.dart의 kKitchenCharacterSizeCorrection과 동일한 목적
const double kRoomCharacterSizeCorrection = 456 / 402;

class ChaeonRoomScreen extends StatefulWidget {
  const ChaeonRoomScreen({super.key, this.initialTemperature = 3});

  final int initialTemperature;

  @override
  State<ChaeonRoomScreen> createState() => _ChaeonRoomScreenState();
}

class _ChaeonRoomScreenState extends State<ChaeonRoomScreen> {
  double _chaeonX = kChaeonRoomX;
  String _chaeonState = 'idle';
  bool _isChaeonFacingLeft = false;

  Timer? _moveTimer;
  // 진입 대사가 끝나기 전까진 dpad랑 문 둘 다 숨김
  bool _dialogueFinished = false;

  bool _isSettingOpen = false;

  // 문 근접 판정 실패 안내 문구, 배경 오브젝트 클릭 정보 둘 다 여기 띄움. 탭하면 닫힘
  String? _interactionText;

  // 배경 오브젝트 클릭 정보 팝업. chapter3_room.json에서 불러온 히트박스 목록이고,
  // kitchen_screen.dart랑 동일하게 이동 가능한 상태(_dialogueFinished)일 때만 클릭 가능
  List<InteractionObject> _interactionObjects = [];

  late final SceneDialogueController _sceneController;

  @override
  void initState() {
    super.initState();
    _sceneController = SceneDialogueController(
      onDialogueEnd: () {
        setState(() => _dialogueFinished = true);
      },
      // 이 방엔 릴리안이 없어서 둘 다 안 씀
      onLillianHop: () {},
      onChaeonHop: () {},
      initialTemperature: widget.initialTemperature,
    );
    _sceneController.addListener(_onSceneControllerChanged);
    _sceneController.loadDialogue(
      'assets/lines/chapter3/chapter3_chaeon_room.json',
    );
    // 배경 오브젝트 클릭 정보(chapter3_room.json) 로드
    InteractionLoader.loadStageObjects('room_bg.png').then((objects) {
      if (mounted) setState(() => _interactionObjects = objects);
    });
  }

  void _onSceneControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _sceneController.removeListener(_onSceneControllerChanged);
    _sceneController.dispose();
    super.dispose();
  }

  void _moveChaeonBy(double delta) {
    setState(() {
      _chaeonX = (_chaeonX + delta).clamp(kChaeonRoomMinX, kChaeonRoomMaxX);
    });
  }

  void _startMoving(int direction) {
    if (!_dialogueFinished) return;
    _moveTimer?.cancel();
    setState(() {
      _chaeonState = 'walk';
      _isChaeonFacingLeft = direction < 0;
    });
    _moveTimer = Timer.periodic(_moveTickInterval, (timer) {
      // 225px/초 * 40ms = 9px, 다른 화면들이랑 동일한 틱당 이동량
      _moveChaeonBy(direction * 9.0);
    });
  }

  void _stopMoving() {
    _moveTimer?.cancel();
    setState(() => _chaeonState = 'idle');
  }

  // 골목길(TutorialScreen)로 이동. 문 근처(kRoomDoorNearMinX~MaxX)에 있을 때만 실제로 이동시키고,
  // 아니면 안내 문구만 잠깐 띄움 (tutorial_screen.dart 빵집 문 isNearDoor 체크랑 동일한 패턴)
  void _handleDoorTap() {
    final bool isNearDoor =
        _chaeonX >= kRoomDoorNearMinX && _chaeonX <= kRoomDoorNearMaxX;
    if (!isNearDoor) {
      setState(() => _interactionText = "아직 문까지는 좀 먼 것 같다.");
      return;
    }
    // TutorialScreen 기본값(골목길 맨 왼쪽에서 시작)을 그대로 써서 진입.
    // chapter3Reentry 켜서 빵집 문 클릭 시 skipChapter1Events 모드로 이어지게 함.
    // initialStep만 2로 넘겨서 조작법 안내 문구(0/1단계)는 건너뜀 (챕터3 재진입이라 이미 다 아는 내용)
    Navigator.push(
      context,
      fadeThroughBlackRoute(
        const TutorialScreen(initialStep: 2, chapter3Reentry: true),
      ),
    );
  }

  void _handleBackButtonTap() {
    _sceneController.goBackScene();
  }

  // 현재 노드가 채온이 대사고 expression이 있으면 그 이미지를 우선 보여줌
  // (kitchen_screen.dart의 _resolveChaeonExpressionSprite와 동일한 패턴)
  String? _resolveChaeonExpressionSprite(String? sceneNodeId) {
    final DialogueNode? node =
        _sceneController.sceneDialogue?.nodes[sceneNodeId];
    if (node?.speaker != 'chaeon') return null;
    return node?.expression?.asset;
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double h = MediaQuery.of(context).size.height;
    // UI 크롬(온도계, 버튼, dpad)은 다른 화면들과 동일 기준(874x402)으로 스케일
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // room_bg.png(874x456)가 화면을 빈틈없이 꽉 채우도록 레터박스 스케일 (kitchen_screen.dart와 동일 공식,
    // 캔버스 세로 크기만 464 대신 456으로 바꿈)
    final double worldScale = (w / 874) > (h / 456) ? (w / 874) : (h / 456);
    final double worldOffsetX = (w - 874 * worldScale) / 2;
    final double worldOffsetY = (h - 456 * worldScale) / 2;
    double wX(double px) => worldOffsetX + px * worldScale;
    double wY(double px) => worldOffsetY + px * worldScale;
    double wSize(double px) => px * worldScale;
    // 채온이 전용 크기: 빵집과 최종 픽셀 크기가 같아 보이도록 kRoomCharacterSizeCorrection만큼
    // 추가로 키움. top은 그대로 두면 커진 만큼 발이 바닥 아래로 파고들어 보이므로, 늘어난 높이의
    // 절반만큼 위로 당겨서 발 위치가 원래 자리에 맞도록 보정함 (kitchen_screen.dart와 동일 패턴)
    final double characterSize = wSize(172) * kRoomCharacterSizeCorrection;
    final double characterTopShift = (characterSize - wSize(172)) / 2;

    final DialogueGraph? sceneDialogue = _sceneController.sceneDialogue;
    final String? sceneNodeId = _sceneController.sceneNodeId;
    final DialogueNode? currentSceneNode =
        (sceneDialogue != null && sceneNodeId != null)
        ? sceneDialogue.nodes[sceneNodeId]
        : null;

    final double chaeonCenterX = wX(_chaeonX) + characterSize / 2;
    final double chaeonSpriteTopY = wY(kChaeonRoomTopY) - characterTopShift;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 배경
            Positioned(
              left: worldOffsetX,
              top: worldOffsetY,
              width: wSize(874),
              height: wSize(456),
              child: Image.asset('assets/images/room_bg.png', fit: BoxFit.fill),
            ),

            // 2층: 채온이. 챕터3 기본 상태는 chaeon_20_normal(_walk).gif(20% 상태 에셋)를 쓰고,
            // 현재 대사 노드에 expression이 있으면(채온이 대사일 때만) 그 이미지를 우선 보여줌
            Positioned(
              key: const ValueKey('chaeon_room_chaeon'),
              left: wX(_chaeonX),
              top: wY(kChaeonRoomTopY) - characterTopShift,
              child: Transform.flip(
                flipX: _isChaeonFacingLeft,
                child: Builder(
                  builder: (context) {
                    final String? expressionSprite =
                        _resolveChaeonExpressionSprite(sceneNodeId);
                    final String defaultSprite = _chaeonState == 'walk'
                        ? 'assets/images/chaeon_20_normal_walk.gif'
                        : 'assets/images/chaeon_20_normal.gif';
                    // expression이 있을 때만 부드럽게 전환하고, 걷기/정지 전환은 dpad에
                    // 바로 반응해야 자연스러워서 즉시 바뀌는 Image.asset을 씀
                    if (expressionSprite != null) {
                      return PopInImage(
                        imagePath: expressionSprite,
                        width: characterSize,
                        height: characterSize,
                        fit: BoxFit.contain,
                      );
                    }
                    return Image.asset(
                      defaultSprite,
                      width: characterSize,
                      height: characterSize,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),

            // 3층: 문 클릭 영역. 대사 끝나야 나타남. 임시 위치라 실제 화면 보면서 조정 필요
            if (_dialogueFinished)
              Positioned(
                key: const ValueKey('chaeon_room_door'),
                left: wX(kRoomDoorX),
                top: wY(kRoomDoorTopY),
                width: wSize(kRoomDoorWidth),
                height: wSize(kRoomDoorHeight),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleDoorTap,
                ),
              ),

            // 3-2층: 배경 오브젝트 클릭 히트박스. kitchen_screen.dart랑 동일하게 이동 가능한 상태
            // (_dialogueFinished)일 때만 활성화하고, 버튼 레이어(5~7층)보다 아래에 둬서
            // 히트박스가 버튼 탭을 가로채지 않게 함
            if (_dialogueFinished)
              for (final obj in _interactionObjects)
                Positioned(
                  key: ValueKey('chaeon_room_interaction_${obj.id}'),
                  left: wX(obj.clickX),
                  top: wY(obj.clickY),
                  width: wSize(obj.width),
                  height: wSize(obj.height),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                      () => _interactionText = obj.dialogue.join('\n'),
                    ),
                  ),
                ),

            // 4층: 진입 대사창
            if (currentSceneNode != null && currentSceneNode.type == 'line')
              Positioned.fill(
                key: const ValueKey('chaeon_room_dialogue_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sceneController.advanceScene,
                  child: Stack(
                    children: [
                      if (currentSceneNode.spans.isNotEmpty &&
                          _sceneController.bubbleRevealed)
                        widgets.buildSceneBubble(
                          node: currentSceneNode,
                          rW: rW,
                          rH: rH,
                          chaeonCenterX: chaeonCenterX,
                          // 이 방엔 릴리안이 없어서 안 쓰이지만 required라 채온이랑 동일값으로 채움
                          lillianCenterX: chaeonCenterX,
                          typedCharCount: _sceneController.typedCharCount,
                          chaeonSpriteTopY: chaeonSpriteTopY,
                          lillianSpriteTopY: chaeonSpriteTopY,
                        ),
                    ],
                  ),
                ),
              ),

            // 5층: 온도계
            widgets.buildThermometer(
              key: 'chaeon_room_thermometer',
              rW: rW,
              rH: rH,
              temperature: _sceneController.temperature,
              temperatureChangeText: _sceneController.temperatureChangeText,
            ),

            // 6층: 뒤로가기 버튼
            widgets.buildBackButton(
              key: 'chaeon_room_back',
              rW: rW,
              rH: rH,
              onTap: _handleBackButtonTap,
            ),

            // 7층: 설정 버튼
            widgets.buildSettingButton(
              key: 'chaeon_room_setting',
              rW: rW,
              rH: rH,
              onTap: () => setState(() => _isSettingOpen = true),
            ),

            // 8층: 가상 패드. 대사 끝나기 전까진 숨김
            if (_dialogueFinished) ...[
              Positioned(
                key: const ValueKey('chaeon_room_dpad_left'),
                left: rW(686),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_left.png',
                  onTapDown: () => _startMoving(-1),
                  onTapUp: _stopMoving,
                  onTapCancel: _stopMoving,
                  rW: rW,
                  rH: rH,
                ),
              ),
              Positioned(
                key: const ValueKey('chaeon_room_dpad_right'),
                left: rW(778),
                bottom: rH(20),
                child: DpadButton(
                  imagePath: 'assets/images/btn_right.png',
                  onTapDown: () => _startMoving(1),
                  onTapUp: _stopMoving,
                  onTapCancel: _stopMoving,
                  rW: rW,
                  rH: rH,
                ),
              ),
            ],

            // 8-2층: 문 근접 실패 안내 팝업 - 화면 아무 곳이나 탭하면 닫힘
            if (_interactionText != null)
              Positioned.fill(
                key: const ValueKey('chaeon_room_interaction_dismiss'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _interactionText = null),
                ),
              ),

            // 8-3층: 문 근접 실패 안내 텍스트창
            if (_interactionText != null)
              widgets.buildInteractionBox(
                text: _interactionText!,
                rW: rW,
                rH: rH,
              ),

            // 9층: 설정 팝업. 다른 화면들이랑 동일한 구성
            if (_isSettingOpen)
              Builder(
                builder: (context) {
                  double popupW = w * 0.8;
                  double popupH = h * 0.8;

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
                    key: const ValueKey('chaeon_room_setting_popup'),
                    child: GestureDetector(
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
