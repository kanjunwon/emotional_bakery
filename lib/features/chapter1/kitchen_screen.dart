// lib/features/chapter1/kitchen_screen.dart
//
// 앞치마 갈아입고 계단을 내려와 도착하는 주방 화면. tutorial_screen.dart처럼 Flame 없이
// 순수 Flutter Positioned/Transform으로만 그림. kitchen_main.png가 화면 한 프레임에
// 다 들어가는 단일 배경이라 카메라 스크롤도 따로 안 둠 (bakery_bg_main.png 같은 와이드 맵이 아님)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/models/interaction_model.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/services/interaction_loader.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter2/bread_making_scene.dart';
import 'package:emotional_bakery/features/chapter2/clock_minigame_scene.dart';
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';
import 'package:emotional_bakery/features/chapter1/game_play_widgets.dart'
    as widgets;
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';

// 채온이가 계단 하강 애니메이션 끝나고 서는 시작 위치 (kitchen_main.png 실측값, 874x464 캔버스 기준)
const double kChaeonKitchenStartX = 60;
const double kChaeonKitchenTopY = 235;
// 릴리안이 고정으로 서있는 위치 (실측값)
const double kLillianKitchenX = 467;
const double kLillianKitchenTopY = 228;
// 채온이가 이 위치 이상 도달하면 이동이 잠기고 kitchen_arrival.json 대사가 자동으로 시작됨
const double kKitchenDialogueTriggerX = 232;
// 채온이가 좌우로 움직일 수 있는 범위 (배경 밖으로 안 나가게)
const double kChaeonKitchenMinX = 60;
const double kChaeonKitchenMaxX = 814;
// 채온이 이동 속도(px/초, 논리 좌표 기준). 챕터1 본편/튜토리얼이랑 동일한 값
const double kChaeonKitchenSpeed = 225;
const Duration _moveTickInterval = Duration(milliseconds: 40);

// 계단을 다시 올라가 빵집으로 돌아가는 연출: 내려올 때(game_play_screen.dart의
// _triggerChaeonStairsDescent)와 동일한 패턴으로, kitchen_main.png 좌표계(874x464) 기준
// 시작/끝 지점과 재생 시간을 지정
const Offset _stairsAscentStart = Offset(60, 235);
const Offset _stairsAscentEnd = Offset(-120, 154);
const Duration _stairsAscentDuration = Duration(milliseconds: 700);

// chapter2_making_bread.json 끝나고 잠깐 암전 유지하는 시간. 임시값, 나중에 실제 연출
// 보면서 조정 예정
const Duration _memoryBlackoutHoldDuration = Duration(seconds: 2);

// 이 화면이 챕터1 엔딩용인지 챕터2 시작용인지 구분. 배경/캐릭터는 같은 주방을 재사용하고
// 이동 가능 여부, 처음 로드하는 대사만 다름
enum KitchenScreenMode {
  // 챕터1 엔딩: dpad로 걸어가서 릴리안 근처에 도달하면 kitchen_arrival.json이 자동 시작됨
  chapter1End,
  // 챕터2 시작: 걷기 없이 화면 들어오자마자 바로 chapter2_ready.json 대사가 시작됨
  chapter2Start,
  // 챕터3 시작: 걷기 없이 화면 들어오자마자 바로 chapter3_chaeon_room_after.json 대사가 시작됨
  chapter3Start,
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

class _KitchenScreenState extends State<KitchenScreen>
    with SingleTickerProviderStateMixin {
  double _chaeonX = kChaeonKitchenStartX;
  String _chaeonState = 'idle';
  bool _isChaeonFacingLeft = false;

  Timer? _moveTimer;
  // 대사 트리거 이후로는 이동 잠금 (dpad도 같이 숨김)
  bool _movementLocked = false;
  // chapter2_after_first_game.json이 끝나면 chaeon_0_eat.gif로 2초간 고정해서 보여줌
  bool _showChaeonEating = false;
  Timer? _chaeonEatingTimer;
  Timer? _chaeonEmotion0to20Timer;
  // kitchen_arrival.json 자동 로드가 중복 실행되지 않게 막는 플래그
  bool _hasTriggeredDialogue = false;

  // 왼쪽 끝에서 계단을 다시 올라가 빵집으로 돌아가는 연출
  late final AnimationController _stairsUpController;
  Animation<Offset>? _stairsUpAnimation;
  bool _isChaeonAscendingStairs = false;

  bool _isSettingOpen = false;
  // kitchen_arrival.json(챕터1)이나 chapter2_ingredient_quiz.json(챕터2)이 끝나면 true.
  // 지금은 안내 문구만 있는 임시 화면으로 대체함
  bool _showChapterEndPlaceholder = false;
  // 챕터2 모드에서 chapter2_ready.json 다음 chapter2_ingredient_quiz.json을 이미 이어붙였는지
  bool _hasLoadedIngredientQuiz = false;
  // 챕터3 모드에서 chapter3_chaeon_room_after.json 다음 chapter3_before_game.json을 이미 이어붙였는지
  bool _hasLoadedBeforeGame = false;
  // chapter2_ingredient_quiz.json의 재료 이름 대사(line_ingredient_reveal)가 끝나고 탭하면 뜨는,
  // 선택한 재료 이미지 팝업. 탭하면 닫힘
  bool _showIngredientPopup = false;
  // 재료 팝업 닫고 chapter2_after_quiz.json을 이미 이어붙였는지
  bool _hasLoadedAfterQuizDialogue = false;
  // chapter2_after_quiz.json 대화가 끝나면 뜨는 빵만들기 미니게임
  bool _showBreadMakingGame = false;
  // 빵만들기 미니게임에서 완성된 반죽 화면을 탭하면(BreadMakingScene.onComplete) 뜨는,
  // 완성된 빵(salt_bread) 팝업. 탭하면 닫힘
  bool _showBreadPopup = false;
  // 빵 팝업 닫고 chapter2_after_first_game.json을 이미 이어붙였는지
  bool _hasLoadedAfterFirstGameDialogue = false;
  // 빵 팝업 닫고 chapter2_making_bread.json을 이미 로드했는지. 이 대사가 끝나야
  // 암전을 거쳐서 chapter2_after_first_game.json으로 이어짐
  bool _hasLoadedMakingBreadDialogue = false;
  // chapter2_making_bread.json 끝나고 chapter2_after_first_game.json 로드하기 전
  // 잠깐 화면을 덮는 암전
  bool _showMemoryBlackout = false;
  Timer? _memoryBlackoutTimer;
  // chaeon_0_eat.gif 노출이 끝나면 뜨는 시계 맞추기 미니게임. 끝나면(onComplete) 임시 종료 화면으로 넘어감
  bool _showClockMinigame = false;
  // 시계 맞추기 미니게임이 끝나면, chapter2_after_second_game.json을 로드하기 전에
  // chaeon_emotion_0to20.gif를 2.5초간 보여줌 (챕터1 chaeon_emotion_0to100.gif와 재생 시간 동일)
  bool _showChaeonEmotion0to20 = false;
  // chapter2_after_second_game.json부터는 채온이가 chaeon_20.gif 상태로 고정됨
  bool _showChaeon20 = false;
  // 시계 맞추기 미니게임 끝나고 chapter2_after_second_game.json을 이미 이어붙였는지
  bool _hasLoadedAfterSecondGameDialogue = false;

  bool _imagesPrecached = false;

  // 배경 오브젝트 클릭 정보 팝업. chapter_kitchen.json에서 불러온 히트박스 목록이고,
  // 방향키가 나와있을 때(!_movementLocked)만 클릭해서 정보를 얻을 수 있음
  List<InteractionObject> _interactionObjects = [];
  String? _interactionText;

  late final SceneDialogueController _sceneController;

  @override
  void initState() {
    super.initState();
    _stairsUpController =
        AnimationController(vsync: this, duration: _stairsAscentDuration)
          ..addListener(() {
            if (mounted) setState(() {});
          });
    _stairsUpController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pop(context);
      }
    });
    // 챕터2는 걷기 없이 바로 대사부터 시작하니까, 이동을 처음부터 잠그고 릴리안 근처에
    // 이미 도착해있는 걸로 시작함
    if (widget.mode == KitchenScreenMode.chapter2Start) {
      _movementLocked = true;
      _chaeonX = kKitchenDialogueTriggerX;
    }
    // 챕터3은 chapter1End랑 동일하게 기본 시작 위치(kChaeonKitchenStartX)에서 dpad로 걸어가서
    // 트리거 지점에 도달해야 대사가 시작됨. 그래서 여기선 따로 잠그지 않음
    _sceneController = SceneDialogueController(
      onDialogueEnd: () {
        // 챕터2 모드는 ready -> ingredient_quiz -> (재료 팝업) -> after_quiz ->
        // (빵만들기 미니게임) -> (빵 팝업) -> after_first_game 순서로 자동 이어붙이고
        // (table.json -> 회상컷씬 -> first_bread.json처럼 대화 끝나면 다음 대화 자동 로드하는
        // 패턴), 그 다음에 끝나면 임시 안내 화면을 띄움
        if (widget.mode == KitchenScreenMode.chapter2Start) {
          if (!_hasLoadedIngredientQuiz) {
            _hasLoadedIngredientQuiz = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter2/chapter2_ingredient_quiz.json',
            );
          } else if (!_hasLoadedAfterQuizDialogue) {
            // line_ingredient_reveal 대사가 끝나면(next: null) 여기로 옴.
            // 선택한 재료 이미지 팝업을 띄우고, 팝업을 닫으면 다음 대사(after_quiz)로 이어짐
            setState(() => _showIngredientPopup = true);
          } else if (_hasLoadedMakingBreadDialogue &&
              !_hasLoadedAfterFirstGameDialogue) {
            // chapter2_making_bread.json이 끝나면(line_001) 여기로 옴. 암전 잠깐 띄웠다가
            // after_first_game.json으로 이어짐. 실제 로드는 _startMemoryBlackout에서 처리
            _startMemoryBlackout();
          } else if (!_hasLoadedAfterFirstGameDialogue) {
            // chapter2_after_quiz.json이 끝나면(line_021) 여기로 옴. 빵만들기 미니게임 시작.
            // 미니게임 완료 -> 빵 팝업 -> after_first_game.json 로드까지는 미니게임/팝업
            // 쪽 콜백(onComplete, 빵 팝업 onTap)에서 처리함
            // (참고: 빵 팝업 onTap은 이제 making_bread.json을 먼저 로드하고, 그 대사가 끝나면
            // 위 _hasLoadedMakingBreadDialogue 분기가 암전 거쳐서 after_first_game.json을 로드함)
            setState(() => _showBreadMakingGame = true);
          } else if (!_hasLoadedAfterSecondGameDialogue) {
            // chapter2_after_first_game.json이 끝나면(line_008) 여기로 옴.
            // 채온이를 chaeon_0_eat.gif로 2초간 고정해서 보여준 뒤 시계 맞추기 미니게임으로 넘어감.
            // 미니게임이 끝나면(ClockMinigameScene.onComplete) chapter2_after_second_game.json으로 이어짐
            setState(() => _showChaeonEating = true);
            _chaeonEatingTimer = Timer(const Duration(milliseconds: 2000), () {
              if (!mounted) return;
              setState(() {
                _showChaeonEating = false;
                _showClockMinigame = true;
              });
            });
          } else {
            // chapter2_after_second_game.json이 끝나면(line_013) 여기로 옴. 임시 종료 화면 표시
            setState(() => _showChapterEndPlaceholder = true);
          }
          return;
        }
        // 챕터3 모드는 chaeon_room_after -> before_game 순으로 자동 이어붙이고
        // (chapter2Start랑 동일한 체이닝 패턴), 아직 미니게임이 없어서 끝나면 임시 안내 화면을 띄움
        if (widget.mode == KitchenScreenMode.chapter3Start) {
          if (!_hasLoadedBeforeGame) {
            _hasLoadedBeforeGame = true;
            _sceneController.loadDialogue(
              'assets/lines/chapter3/chapter3_before_game.json',
            );
          } else {
            // chapter3_before_game.json이 끝나면(line_029, "네!") 여기로 옴. 임시 종료 화면 표시
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
    // 배경 오브젝트 클릭 정보(chapter_kitchen.json) 로드
    InteractionLoader.loadStageObjects('kitchen_main.png').then((objects) {
      if (mounted) setState(() => _interactionObjects = objects);
    });
    // 챕터2는 걷기 없이 화면 들어오자마자 바로 대사 시작
    if (widget.mode == KitchenScreenMode.chapter2Start) {
      _sceneController.loadDialogue('assets/lines/chapter2/chapter2_ready.json');
    }
    // 챕터3은 chapter1End처럼 트리거 지점 도달 시 _checkDialogueTrigger에서 로드하므로 여기선 안 함
  }

  void _onSceneControllerChanged() {
    if (mounted) setState(() {});
  }

  // 시계 맞추기 미니게임이 끝나면 chaeon_emotion_0to20.gif를 3초간 보여준 뒤,
  // chaeon_20.gif 상태로 넘어가면서 chapter2_after_second_game.json을 이어붙임.
  void _loadSecondGameDialogueAfterEmotionGif() {
    _chaeonEmotion0to20Timer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      setState(() {
        _showChaeonEmotion0to20 = false;
        _showChaeon20 = true;
      });
      _hasLoadedAfterSecondGameDialogue = true;
      _sceneController.loadDialogue(
        'assets/lines/chapter2/chapter2_after_second_game.json',
      );
    });
  }

  // chapter2_making_bread.json 끝나면 화면을 잠깐 암전시켰다가 after_first_game.json으로
  // 넘어감. 대기 시간은 _memoryBlackoutHoldDuration 임시값, 나중에 실제 연출 보면서 조정 예정
  void _startMemoryBlackout() {
    setState(() => _showMemoryBlackout = true);
    _memoryBlackoutTimer = Timer(_memoryBlackoutHoldDuration, () {
      if (!mounted) return;
      setState(() => _showMemoryBlackout = false);
      _hasLoadedAfterFirstGameDialogue = true;
      _sceneController.loadDialogue(
        'assets/lines/chapter2/chapter2_after_first_game.json',
      );
    });
  }

  // 이미지 프리캐싱: 첫 빌드 시점에 한 번만 실행
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/kitchen_main.png',
        'assets/images/chaeon_apron_putting_on.gif',
        'assets/images/chaeon_apron_idle.gif',
        'assets/images/lillian_idle.gif',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
      // kitchen_arrival.json / 챕터2 대화 파일들 특정 노드에서 잠깐 바뀌는 릴리안
      // 스프라이트도 미리 프리캐싱
      for (final asset in widgets.kitchenArrivalLillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      for (final overrides
          in widgets.chapter2LillianSpriteOverridesByDialogueId.values) {
        for (final asset in overrides.values) {
          precacheImage(AssetImage(asset), context);
        }
      }
    }
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _chaeonEatingTimer?.cancel();
    _chaeonEmotion0to20Timer?.cancel();
    _memoryBlackoutTimer?.cancel();
    _stairsUpController.dispose();
    _sceneController.removeListener(_onSceneControllerChanged);
    _sceneController.dispose();
    super.dispose();
  }

  // 채온이를 delta만큼 옮기고(배경 밖으로는 안 나가게 clamp), 대사 트리거/왼쪽 끝(계단) 트리거 확인
  void _moveChaeonBy(double delta) {
    setState(() {
      _chaeonX = (_chaeonX + delta).clamp(
        kChaeonKitchenMinX,
        kChaeonKitchenMaxX,
      );
    });
    _checkDialogueTrigger();
    _checkStairsUpTrigger(delta);
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
      // 챕터3 모드는 kitchen_arrival.json 대신 chapter3_chaeon_room_after.json을 로드함
      _sceneController.loadDialogue(
        widget.mode == KitchenScreenMode.chapter3Start
            ? 'assets/lines/chapter3/chapter3_chaeon_room_after.json'
            : 'assets/lines/chapter1/kitchen_arrival.json',
      );
    }
  }

  // 왼쪽 끝(계단 있는 곳)까지 계속 왼쪽으로 이동하려 하면 다시 계단을 올라가 빵집으로 돌아감.
  // 챕터1 모드(GamePlayScreen에서 push된 경우)에서만 돌아갈 화면이 있으므로 그때만 동작
  bool _hasTriggeredStairsUp = false;
  void _checkStairsUpTrigger(double delta) {
    if (_hasTriggeredStairsUp) return;
    if (widget.mode != KitchenScreenMode.chapter1End) return;
    if (delta < 0 && _chaeonX <= kChaeonKitchenMinX) {
      _hasTriggeredStairsUp = true;
      _moveTimer?.cancel();
      setState(() {
        _movementLocked = true;
        _chaeonState = 'idle';
      });
      _triggerChaeonStairsAscent();
    }
  }

  // 내려올 때(game_play_screen.dart의 _triggerChaeonStairsDescent)와 동일한 패턴으로,
  // _stairsAscentStart에서 _stairsAscentEnd로 이동하는 애니메이션을 재생. 끝나면 화면을 pop함
  void _triggerChaeonStairsAscent() {
    _stairsUpAnimation =
        Tween<Offset>(
          begin: _stairsAscentStart,
          end: _stairsAscentEnd,
        ).animate(
          CurvedAnimation(parent: _stairsUpController, curve: Curves.easeIn),
        );
    setState(() => _isChaeonAscendingStairs = true);
    _stairsUpController.forward(from: 0);
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

  // 현재 노드에 expression이 있으면 그 표정으로, 없으면 기본 idle GIF로
  String _resolveLillianSprite(String? sceneNodeId) {
    final String? expressionAsset =
        _sceneController.sceneDialogue?.nodes[sceneNodeId]?.expression?.asset;
    if (expressionAsset != null) return expressionAsset;
    return 'assets/images/lillian_idle.gif';
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
    // UI 크롬(온도계, 버튼, dpad 등 화면 가장자리에 고정되는 요소)은 game_play_screen.dart(빵집)와
    // 완전히 동일한 기준(874x402)으로 스케일해야 크기/위치가 두 화면에서 똑같이 보임
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // 배경(kitchen_main.png)이 항상 화면을 빈틈없이 꽉 채우도록, 가로/세로 중 더 많이
    // 확대해야 하는 쪽 기준으로 스케일함(cover). 가로 기준(w/874)만 쓰면 창을 세로로
    // 늘렸을 때 계산된 배경 높이가 실제 화면 높이보다 작아져서 위쪽에 빈 공간이 생겼음
    final double worldScale = (w / 874) > (h / 464) ? (w / 874) : (h / 464);
    // 가로가 남으면(세로로 긴 창) 좌우를 대칭으로 잘라내고, 세로가 남으면(원래 케이스)
    // 이미지 하단에서 8px 위 지점(월드 좌표 464-8=456)이 화면 하단에 오도록 맞춤
    final double worldOffsetX = (w - 874 * worldScale) / 2;
    final double worldOffsetY = h - (464 - 8) * worldScale;
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

    // 채온이/릴리안 둘 다 Positioned의 left가 스프라이트 왼쪽 끝 기준이라(중앙 기준 보정 없음),
    // 말풍선 가로 중심은 거기에 스프라이트 폭의 절반을 더해야 실제 캐릭터 중심과 맞음
    final double chaeonCenterX = wX(_chaeonX) + wSize(172) / 2;
    final double lillianCenterX = wX(kLillianKitchenX) + wSize(172) / 2;
    // 말풍선 앵커: 각 캐릭터가 실제로 서있는 kitchen_main.png 좌표(wY) 기준
    final double chaeonSpriteTopY = wY(kChaeonKitchenTopY);
    final double lillianSpriteTopY = wY(kLillianKitchenTopY);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 배경. 874:464 비율 유지한 채로 화면을 빈틈없이 꽉 채움
            // (화면 비율이 안 맞으면 초과분은 좌우 또는 위쪽이 화면 밖으로 잘려나감)
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
                _resolveLillianSprite(sceneNodeId),
                width: wSize(172),
                height: wSize(172),
                fit: BoxFit.contain,
              ),
            ),

            // 3층: 채온이. dpad로 좌우 이동, 대사 트리거 이후로는 제자리에 고정.
            // 앞치마 입고 걷는 전용 애니메이션 에셋이 아직 없어서, game_play_screen.dart의
            // kitchenApproach 단계와 동일하게 walk 상태일 땐 chaeon_apron_idle.gif를,
            // idle 상태일 땐 chaeon_apron_putting_on.gif를 대신 보여줌
            Positioned(
              key: const ValueKey('kitchen_chaeon'),
              left: wX(
                _isChaeonAscendingStairs
                    ? (_stairsUpAnimation?.value.dx ?? _chaeonX)
                    : _chaeonX,
              ),
              top: wY(
                _isChaeonAscendingStairs
                    ? (_stairsUpAnimation?.value.dy ?? kChaeonKitchenTopY)
                    : kChaeonKitchenTopY,
              ),
              child: Transform.flip(
                flipX: _isChaeonFacingLeft,
                child: Image.asset(
                  // chapter2_after_first_game.json 종료 직후엔 chaeon_0_eat.gif, 시계
                  // 미니게임 이후엔 chaeon_emotion_0to20.gif -> chaeon_20.gif 순으로,
                  // 다른 상태와 무관하게 우선 보여줌. 계단을 올라가는 중엔 그 시점
                  // _chaeonState와 무관하게 항상 apron_idle.gif로 고정
                  // (game_play_screen.dart의 하강 연출과 동일한 규칙)
                  _showChaeonEating
                      ? 'assets/images/chaeon_0_eat.gif'
                      : _showChaeonEmotion0to20
                      ? 'assets/images/chaeon_emotion_0to20.gif'
                      : _showChaeon20
                      ? 'assets/images/chaeon_20.gif'
                      : _isChaeonAscendingStairs || _chaeonState == 'walk'
                      ? 'assets/images/chaeon_apron_idle.gif'
                      : 'assets/images/chaeon_apron_putting_on.gif',
                  width: wSize(172),
                  height: wSize(172),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 3-2층: 배경 오브젝트 클릭 히트박스. 방향키가 나와있을 때(!_movementLocked)만 활성화.
            // 온도계/뒤로가기/설정 버튼(5~7층)보다 아래에 있어야 버튼 영역과 겹치는 히트박스가
            // 버튼 탭을 가로채지 않음 (겹치면 버튼이 안 눌리는 문제가 생김)
            if (!_movementLocked)
              for (final obj in _interactionObjects)
                Positioned(
                  key: ValueKey('kitchen_interaction_${obj.id}'),
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
                          // 각 캐릭터 머리 위에 바로 붙도록 실제 스프라이트 top을 넘겨줌
                          chaeonSpriteTopY: chaeonSpriteTopY,
                          lillianSpriteTopY: lillianSpriteTopY,
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
                        // 각 캐릭터 머리 위에 바로 붙도록 실제 스프라이트 top을 넘겨줌
                        chaeonSpriteTopY: chaeonSpriteTopY,
                        lillianSpriteTopY: lillianSpriteTopY,
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

            // 8-2층: 오브젝트 클릭 정보성 팝업 - 화면 아무 곳이나 탭하면 닫힘
            if (_interactionText != null)
              Positioned.fill(
                key: const ValueKey('kitchen_interaction_dismiss'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _interactionText = null),
                ),
              ),

            // 8-3층: 오브젝트 클릭 정보성 팝업 텍스트창
            if (_interactionText != null)
              widgets.buildInteractionBox(
                text: _interactionText!,
                rW: rW,
                rH: rH,
              ),

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

            // 9-2층: 재료 획득 팝업. chapter2_ingredient_quiz.json의 재료 이름 대사가 끝나고
            // 탭하면 뜸. tutorial_dialogue_box(570x300) 뒤에 검은 50% 배경, 그 위에
            // 선택한 재료 이미지 표시. 탭하면 닫히고 chapter2_after_quiz.json으로 이어짐
            if (_showIngredientPopup)
              Positioned.fill(
                key: const ValueKey('ingredient_popup_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showIngredientPopup = false);
                    _hasLoadedAfterQuizDialogue = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter2/chapter2_after_quiz.json',
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        width: rW(570),
                        height: rH(300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 그냥 Image.asset + BoxFit.fill로 그리면 원본 이미지 비율
                            // (1119x285)이랑 팝업 비율이 많이 달라서 테두리가 가로/세로로
                            // 다르게 늘어나 깨져 보임. DialogueBoxFrame이랑 동일하게
                            // centerSlice(9-slice)로 그려서 모서리 두께를 유지함
                            Container(
                              width: rW(570),
                              height: rH(300),
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'assets/images/tutorial_dialogue_box.png',
                                  ),
                                  fit: BoxFit.fill,
                                  centerSlice: tutorialDialogueBoxCenterSlice,
                                ),
                              ),
                            ),
                            if (StoryState.resolveIngredientImage() != null)
                              Image.asset(
                                StoryState.resolveIngredientImage()!,
                                width: rW(300),
                                height: rH(300),
                                fit: BoxFit.contain,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 9-3층: 빵만들기 미니게임. chapter2_after_quiz.json 대화가 끝나면 뜨고,
            // 최상단에서 화면을 전부 덮음. 완성된 반죽 화면을 탭하면 주방으로 돌아가고
            // 빵 팝업이 뜸(onComplete)
            if (_showBreadMakingGame)
              Positioned.fill(
                key: const ValueKey('bread_making_game'),
                child: BreadMakingScene(
                  onComplete: () {
                    setState(() {
                      _showBreadMakingGame = false;
                      _showBreadPopup = true;
                    });
                  },
                ),
              ),

            // 9-4층: 완성된 빵(salt_bread) 팝업. 빵만들기 게임에서 완성 화면을 탭해 주방으로
            // 돌아오면 뜸. 재료 획득 팝업이랑 동일한 연출(검은 50% 배경 + tutorial_dialogue_box
            // 570x300 + 이미지 300x300). 탭하면 닫히고 chapter2_after_first_game.json으로 이어짐
            if (_showBreadPopup)
              Positioned.fill(
                key: const ValueKey('bread_popup_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showBreadPopup = false);
                    // after_first_game.json으로 바로 안 가고 making_bread.json부터 거침.
                    // 끝나면 onDialogueEnd의 _hasLoadedMakingBreadDialogue 분기가 이어받음
                    _hasLoadedMakingBreadDialogue = true;
                    _sceneController.loadDialogue(
                      'assets/lines/chapter2/chapter2_making_bread.json',
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        width: rW(570),
                        height: rH(300),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: rW(570),
                              height: rH(300),
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'assets/images/tutorial_dialogue_box.png',
                                  ),
                                  fit: BoxFit.fill,
                                  centerSlice: tutorialDialogueBoxCenterSlice,
                                ),
                              ),
                            ),
                            Image.asset(
                              'assets/images/salt_bread.png',
                              width: rW(300),
                              height: rH(300),
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 9-5층: 시계 맞추기 미니게임. 빵 팝업 -> chapter2_after_first_game.json ->
            // chaeon_0_eat.gif 노출이 다 끝나면 뜨고, 최상단에서 화면을 전부 덮음.
            // 끝나면(onComplete) chaeon_emotion_0to20.gif를 보여준 뒤
            // chapter2_after_second_game.json으로 이어짐
            if (_showClockMinigame)
              Positioned.fill(
                key: const ValueKey('clock_minigame'),
                child: ClockMinigameScene(
                  onComplete: () {
                    setState(() {
                      _showClockMinigame = false;
                      _showChaeonEmotion0to20 = true;
                    });
                    _loadSecondGameDialogueAfterEmotionGif();
                  },
                ),
              ),

            // 9-6층: chapter2_making_bread.json 끝나고 after_first_game.json 로드하기 전
            // 잠깐 띄우는 암전. memory_flashback_scene.dart / clock_minigame_scene.dart에서
            // 쓰는 검은 Container + Timer 패턴 그대로 씀. 대기 시간은 _memoryBlackoutHoldDuration
            if (_showMemoryBlackout)
              Positioned.fill(
                key: const ValueKey('memory_blackout'),
                child: Container(color: Colors.black),
              ),

            // 10층: 챕터 종료/진행 임시 화면. 나중에 진짜 종료 연출/다음 챕터 연결로 교체할 예정이라
            // 지금은 암전 + 중앙 안내 문구만 있는 자리표시자로 둠. 탭하면 챕터 선택창으로 이동.
            // 챕터1 모드면 "챕터 1 종료", 챕터2 모드면 "챕터 2 종료" 문구로 나뉨
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
                                : widget.mode == KitchenScreenMode.chapter2Start
                                ? '챕터 2 종료'
                                : '챕터3 미니게임 준비 중',
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
