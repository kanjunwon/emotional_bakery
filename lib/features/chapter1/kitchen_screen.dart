// lib/features/chapter1/kitchen_screen.dart
//
// 앞치마 갈아입고 계단을 내려와 도착하는 주방 화면. tutorial_screen.dart처럼 Flame 없이
// 순수 Flutter Positioned/Transform으로만 그림. kitchen_main.png가 화면 한 프레임에
// 다 들어가는 단일 배경이라 카메라 스크롤도 따로 안 둠 (bakery_bg_main.png 같은 와이드 맵이 아님)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';

// 채온이가 계단 하강 애니메이션 끝나고 서는 시작 위치 (kitchen_main.png 실측값, 874x464 캔버스 기준)
const double kChaeonKitchenStartX = 231;
const double kChaeonKitchenTopY = 181;
// 릴리안이 고정으로 서있는 위치 (실측값)
const double kLillianKitchenX = 467;
const double kLillianKitchenTopY = 176;
// 채온이가 이 위치 이상 도달하면 이동이 잠기고 kitchen_arrival.json 대사가 자동으로 시작됨.
// 릴리안 위치(kLillianKitchenX)보다 100px 앞에서 멈추게 재계산한 값
const double kKitchenDialogueTriggerX = kLillianKitchenX - 100;
// 채온이가 좌우로 움직일 수 있는 범위 (배경 밖으로 안 나가게)
const double kChaeonKitchenMinX = 60;
const double kChaeonKitchenMaxX = 814;
// 채온이 이동 속도(px/초, 논리 좌표 기준). 챕터1 본편/튜토리얼이랑 동일한 값
const double kChaeonKitchenSpeed = 225;
const Duration _moveTickInterval = Duration(milliseconds: 40);

// 이 화면이 챕터1 엔딩용인지 챕터2 시작용인지 구분. 배경/캐릭터는 같은 주방을 재사용하고
// 이동 가능 여부, 처음 로드하는 대사만 다름
enum KitchenScreenMode {
  // 챕터1 엔딩: dpad로 걸어가서 릴리안 근처에 도달하면 kitchen_arrival.json이 자동 시작됨
  chapter1End,
  // 챕터2 시작: 걷기 없이 화면 들어오자마자 바로 chapter2_ready.json 대사가 시작됨
  chapter2Start,
}

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({
    super.key,
    this.initialTemperature = 3,
    this.mode = KitchenScreenMode.chapter1End,
  });

  // GamePlayScreen에서 이어받는 온도계 값 (화면이 바뀌어도 온도계가 끊기지 않게)
  final int initialTemperature;
  final KitchenScreenMode mode;

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  double _chaeonX = kChaeonKitchenStartX;
  String _chaeonState = 'idle';
  bool _isChaeonFacingLeft = false;

  Timer? _moveTimer;
  // 대사 트리거 이후로는 이동 잠금 (dpad도 같이 숨김)
  bool _movementLocked = false;
  // kitchen_arrival.json 자동 로드가 중복 실행되지 않게 막는 플래그
  bool _hasTriggeredDialogue = false;

  bool _isSettingOpen = false;
  // kitchen_arrival.json(챕터1)이나 chapter2_ingredient_quiz.json(챕터2)이 끝나면 true.
  // 지금은 안내 문구만 있는 임시 화면으로 대체함
  bool _showChapterEndPlaceholder = false;
  // 챕터2 모드에서 chapter2_ready.json 다음 chapter2_ingredient_quiz.json을 이미 이어붙였는지
  bool _hasLoadedIngredientQuiz = false;

  bool _imagesPrecached = false;

  late final SceneDialogueController _sceneController;

  @override
  void initState() {
    super.initState();
    // 챕터2는 걷기 없이 바로 대사부터 시작하니까, 이동을 처음부터 잠그고 릴리안 근처에
    // 이미 도착해있는 걸로 시작함
    if (widget.mode == KitchenScreenMode.chapter2Start) {
      _movementLocked = true;
      _chaeonX = kKitchenDialogueTriggerX;
    }
    _sceneController = SceneDialogueController(
      onDialogueEnd: () {
        // 챕터2 모드는 ready -> ingredient_quiz 순서로 자동 이어붙이고, 그 다음에 끝나면
        // (table.json -> 회상컷씬 -> first_bread.json처럼 대화 끝나면 다음 대화 자동 로드하는 패턴)
        // 임시 안내 화면을 띄움
        if (widget.mode == KitchenScreenMode.chapter2Start) {
          if (!_hasLoadedIngredientQuiz) {
            _hasLoadedIngredientQuiz = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter2/chapter2_ingredient_quiz.json',
            );
          } else {
            setState(() => _showChapterEndPlaceholder = true);
          }
          return;
        }
        // kitchen_arrival.json 종료 = 챕터 1 종료 시점.
        // TODO: 나중에 진짜 챕터1 종료 연출/다음 챕터 연결로 교체할 예정. 지금은 임시 안내 문구만 표시
        setState(() => _showChapterEndPlaceholder = true);
      },
      // kitchen_arrival.json에는 hop 트리거용 animation 필드가 없어서 둘 다 안 씀
      onLillianHop: () {},
      onChaeonHop: () {},
      initialTemperature: widget.initialTemperature,
    );
    _sceneController.addListener(_onSceneControllerChanged);
    // 챕터2는 걷기 없이 화면 들어오자마자 바로 대사 시작
    if (widget.mode == KitchenScreenMode.chapter2Start) {
      _sceneController.loadDialogue(
        'assets/lines/chapter2/chapter2_ready.json',
      );
    }
  }

  void _onSceneControllerChanged() {
    if (mounted) setState(() {});
  }

  // 이미지 프리캐싱: 첫 빌드 시점에 한 번만 실행
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/kitchen_main.png',
        'assets/images/chaeon_idle_right.gif',
        'assets/images/chaeon_walk_right.gif',
        'assets/images/lillian_idle.gif',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _sceneController.removeListener(_onSceneControllerChanged);
    _sceneController.dispose();
    super.dispose();
  }

  // 채온이를 delta만큼 옮기고(배경 밖으로는 안 나가게 clamp), 대사 트리거 지점 도달했는지 확인
  void _moveChaeonBy(double delta) {
    setState(() {
      _chaeonX = (_chaeonX + delta).clamp(
        kChaeonKitchenMinX,
        kChaeonKitchenMaxX,
      );
    });
    _checkDialogueTrigger();
  }

  // 릴리안 근처(대사 트리거 x좌표)에 도달하면 이동 잠그고 kitchen_arrival.json 자동 시작
  void _checkDialogueTrigger() {
    if (_hasTriggeredDialogue) return;
    if (_chaeonX >= kKitchenDialogueTriggerX) {
      _hasTriggeredDialogue = true;
      _moveTimer?.cancel();
      setState(() {
        _movementLocked = true;
        _chaeonState = 'idle';
      });
      _sceneController.loadDialogue(
        'assets/lines/chapter1/kitchen_arrival.json',
      );
    }
  }

  void _startMoving(int direction) {
    if (_movementLocked) return;
    _moveTimer?.cancel();
    setState(() {
      _chaeonState = 'walk';
      _isChaeonFacingLeft = direction < 0;
    });
    _moveTimer = Timer.periodic(_moveTickInterval, (timer) {
      // 225px/초 * 40ms = 9px, 튜토리얼 화면이랑 동일한 틱당 이동량
      _moveChaeonBy(direction * 9.0);
    });
  }

  void _stopMoving() {
    _moveTimer?.cancel();
    if (!_movementLocked) {
      setState(() => _chaeonState = 'idle');
    }
  }

  // 뒤로가기 버튼: 타이핑 중이면 텍스트 다 보여주고, 아니면 이전 대사로 되돌아감
  void _handleBackButtonTap() {
    _sceneController.goBackScene();
  }

  // 챕터 1 종료 임시 화면 탭하면 챕터 선택창으로 이동. tutorial_screen.dart에서 빵집 문 클릭 시
  // GamePlayScreen으로 넘어가는 것과 동일하게 pushReplacement로 스택 정리
  void _handleChapterEndTap() {
    // 챕터1 엔딩을 다 봤으니 챕터2 해금. 챕터2 모드(이미 해금된 상태)에서 탭할 땐 안 해도 됨
    if (widget.mode == KitchenScreenMode.chapter1End) {
      ChapterProgress.isChapter2Unlocked = true;
    }
    Navigator.pushReplacement(
      context,
      fadeThroughBlackRoute(const ChapterSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double h = MediaQuery.of(context).size.height;
    // UI 크롬(온도계, 버튼, dpad 등 화면 가장자리에 고정되는 요소)은 화면 전체 기준으로 그대로 씀
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 464) * h;

    // 배경(kitchen_main.png)은 874:464 비율을 유지한 채 레터박스로 화면 안에 통째로 들어오게 함.
    // 화면 비율이 이거보다 넓으면 세로에 꽉 맞추고 좌우에 여백, 좁으면 가로에 꽉 맞추고 위아래 여백
    const double kitchenAspect = 874 / 464;
    final double screenAspect = w / h;
    late final double worldScale;
    late final double worldOffsetX;
    late final double worldOffsetY;
    if (screenAspect > kitchenAspect) {
      worldScale = h / 464;
      worldOffsetX = (w - 874 * worldScale) / 2;
      worldOffsetY = 0;
    } else {
      worldScale = w / 874;
      worldOffsetX = 0;
      worldOffsetY = (h - 464 * worldScale) / 2;
    }
    // 배경 이미지 안 좌표(월드 좌표)를 실제 화면 좌표로 바꿔줌. 위치는 레터박스 오프셋을 더해야 하고,
    // 크기(width/height)는 오프셋 없이 scale만 곱하면 됨
    double wX(double px) => worldOffsetX + px * worldScale;
    double wY(double px) => worldOffsetY + px * worldScale;
    double wSize(double px) => px * worldScale;

    final DialogueGraph? sceneDialogue = _sceneController.sceneDialogue;
    final String? sceneNodeId = _sceneController.sceneNodeId;
    final DialogueNode? currentSceneNode =
        (sceneDialogue != null && sceneNodeId != null)
        ? sceneDialogue.nodes[sceneNodeId]
        : null;

    final double chaeonCenterX = wX(_chaeonX);
    final double lillianCenterX = wX(kLillianKitchenX);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 배경. 874:464 비율 유지한 채로 레터박스로 화면 안에 통째로 들어오게 함
            // (화면 비율이 안 맞으면 좌우나 위아래에 검은 여백이 생김)
            Positioned(
              left: worldOffsetX,
              top: worldOffsetY,
              width: wSize(874),
              height: wSize(464),
              child: Image.asset(
                'assets/images/kitchen_main.png',
                fit: BoxFit.fill,
              ),
            ),

            // 2층: 릴리안. 화면 안 고정된 위치에 정지 상태(idle)로 서있음
            Positioned(
              key: const ValueKey('kitchen_lillian'),
              left: wX(kLillianKitchenX),
              top: wY(kLillianKitchenTopY),
              child: Image.asset(
                'assets/images/lillian_idle.gif',
                width: wSize(172),
                height: wSize(172),
                fit: BoxFit.contain,
              ),
            ),

            // 3층: 채온이. dpad로 좌우 이동, 대사 트리거 이후로는 제자리에 고정
            Positioned(
              key: const ValueKey('kitchen_chaeon'),
              left: wX(_chaeonX),
              top: wY(kChaeonKitchenTopY),
              child: Transform.flip(
                flipX: _isChaeonFacingLeft,
                child: Image.asset(
                  _chaeonState == 'walk'
                      ? 'assets/images/chaeon_walk_right.gif'
                      : 'assets/images/chaeon_idle_right.gif',
                  width: wSize(172),
                  height: wSize(172),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 4층: kitchen_arrival.json 대사창. SceneDialogueController + buildSceneBubble 그대로 재사용
            if (currentSceneNode != null && currentSceneNode.type == 'line')
              Positioned.fill(
                key: const ValueKey('kitchen_dialogue_layer'),
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
                          lillianCenterX: lillianCenterX,
                          typedCharCount: _sceneController.typedCharCount,
                        ),
                    ],
                  ),
                ),
              ),

            // 4-2층: choice 노드 대사창. game_play_screen.dart 13층이랑 동일한 패턴으로
            // 직전 line 노드 말풍선(lastLineNode)은 어두운 배경 아래 계속 보여주고, 그 위에
            // 선택지 버튼을 띄움. onChooseOption에서 chooseSceneOption 호출해서 다음 노드로 진행
            if (currentSceneNode != null && currentSceneNode.type == 'choice')
              Positioned.fill(
                key: const ValueKey('kitchen_choice_layer'),
                child: Stack(
                  children: [
                    if (_sceneController.lastLineNode != null)
                      widgets.buildSceneBubble(
                        node: _sceneController.lastLineNode!,
                        rW: rW,
                        rH: rH,
                        chaeonCenterX: chaeonCenterX,
                        lillianCenterX: lillianCenterX,
                        typedCharCount: _sceneController.typedCharCount,
                        charCount: _sceneController.lastLineNode!.spans
                            .fold<int>(0, (sum, s) => sum + s.text.length),
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

            // 5층: 온도계 (기존 화면들이랑 톤 맞추려고 그대로 재사용)
            widgets.buildThermometer(
              key: 'kitchen_thermometer',
              rW: rW,
              rH: rH,
              temperature: _sceneController.temperature,
              temperatureChangeText: _sceneController.temperatureChangeText,
            ),

            // 6층: 뒤로가기 버튼
            widgets.buildBackButton(
              key: 'kitchen_back',
              rW: rW,
              rH: rH,
              onTap: _handleBackButtonTap,
            ),

            // 7층: 설정 버튼
            widgets.buildSettingButton(
              key: 'kitchen_setting',
              rW: rW,
              rH: rH,
              onTap: () => setState(() => _isSettingOpen = true),
            ),

            // 8층: 가상 패드. 이동 잠기면(대사 트리거 이후) 숨김
            if (!_movementLocked) ...[
              Positioned(
                key: const ValueKey('kitchen_dpad_left'),
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
                key: const ValueKey('kitchen_dpad_right'),
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

            // 9층: 설정 팝업. game_play_screen.dart 설정 팝업이랑 동일한 구성
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
                    key: const ValueKey('kitchen_setting_popup'),
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

            // 10층: 챕터 종료/진행 임시 화면. 나중에 진짜 종료 연출/다음 챕터 연결로 교체할 예정이라
            // 지금은 암전 + 중앙 안내 문구만 있는 자리표시자로 둠. 탭하면 챕터 선택창으로 이동.
            // 챕터1 모드면 "챕터 1 종료", 챕터2 모드면 "챕터 2 계속 준비 중" 문구로 나뉨
            if (_showChapterEndPlaceholder)
              Positioned.fill(
                key: const ValueKey('chapter_end_placeholder'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleChapterEndTap,
                  child: Container(
                    color: Colors.black.withOpacity(0.85),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.mode == KitchenScreenMode.chapter1End
                                ? '챕터 1 종료'
                                : '챕터 2 계속 준비 중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: rW(28),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SCDream',
                            ),
                          ),
                          SizedBox(height: rH(16)),
                          // 임시 화면이라 안내도 짧게: 탭하면 챕터 선택창으로 넘어감
                          Text(
                            '화면을 탭하면 챕터 선택창으로 이동합니다',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: rW(14),
                              fontFamily: 'SCDream',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
