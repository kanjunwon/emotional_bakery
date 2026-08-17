// lib/features/chapter1/game_play_screen.dart

import 'dart:async';
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
import 'package:emotional_bakery/features/chapter1/memory_flashback_scene.dart';
import 'package:emotional_bakery/features/chapter1/kitchen_screen.dart';

// 챕터1 대사 체이닝 진행 단계: first_meet → table → 회상 컷씬 → first_bread → 앞치마 착용 후 주방행
enum DialoguePhase {
  none,
  firstMeet,
  table,
  memoryFlashback,
  firstBread,
  // 앞치마 착용 후 주방으로 내려가는 연출 단계. 이때부터 계단 트리거가 실제로 소모되게 켜짐
  kitchenApproach,
}

// table.json 종료 후 회상 컷씬으로 넘어갈 때 쓰는 검은 화면 페이드 전환 타이밍
const Duration _memoryFadeInDuration = Duration(milliseconds: 300);
const Duration _memoryFadeHoldDuration = Duration(milliseconds: 1000);
const Duration _memoryFadeOutDuration = Duration(milliseconds: 300);

// 계단 하강 연출용 상수: 계단 꼭대기 지점, 계단 화면 밖 지점, 채온이 계단 내려가는 끝 지점, 하강 애니메이션 지속시간
const Offset _stairsTopPoint = Offset(1680, 172);
// 릴리안이 계단을 올라오기 시작하는(화면 밖) 지점
const Offset _stairsOffscreenPoint = Offset(1800, 180);
// 채온이가 계단을 내려가 화면 밖으로 사라지는 지점
const Offset _chaeonStairsDescentEnd = Offset(1920, 232);
const Duration _stairsDescentDuration = Duration(milliseconds: 700);

class GamePlayScreen extends StatefulWidget {
  final bool isPrologue;
  // 챕터3 재진입 모드: true면 가이드 대사/table.json/first_bread.json 단계를 전부 건너뛰고,
  final bool skipChapter1Events;
  const GamePlayScreen({
    super.key,
    this.isPrologue = false,
    this.skipChapter1Events = false,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with TickerProviderStateMixin {
  late final BakeryGame _game;

  bool _isDialogueActive = false;
  int _dialogueStep = 0;
  List<String> _dialogueTexts = [];
  String? _interactionText;
  bool _isSettingOpen = false;

  // 채온이 상태 변수
  String _chaeonState = 'idle';
  bool _isChaeonFacingRight = true; // 채온 좌우 반전용 스위치
  // table.json 먹는 클로즈업을 한 번이라도 지나갔는지. true가 되면 회상 컷씬으로 넘어갈 때까지
  // 빵 접시를 다시 그리지 않고, 채온이도 빵 든 정지 이미지로 표시
  bool _hasEatenBread = false;

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

  // 채온이가 계단 근처에 도달했을 때 재생하는 하강 애니메이션(_stairsTopPoint -> _chaeonStairsDescentEnd)
  late AnimationController _chaeonStairsDescentController;
  Animation<Offset>? _chaeonStairsDescentAnimation;
  bool _isChaeonDescendingStairs = false;
  // 계단 하강 후 주방 화면으로 전환 중 중복 네비게이션 방지 플래그
  bool _isNavigatingToKitchen = false;

  // 릴리안/채온 "깜짝 놀람" 모션(살짝 위로 껑충)용 컨트롤러 및 오프셋 애니메이션
  late AnimationController _lillianHopController;
  late Animation<double> _lillianHopOffset;
  late AnimationController _chaeonHopController;
  late Animation<double> _chaeonHopOffset;

  // 암전 시작시, true 고정. 이때부터 온도계/뒤로가기 노출, 이동 버튼 숨김
  bool _isGuidePhaseStarted = false;
  // 첫 만남 대사 종료 후, 채온이가 1200 지점에 도착하면 true. 이때부터 방향키 숨김, 이동 잠금
  bool _isFreeWalkPhase = false;

  // 현재 어느 대사 단계인지: first_meet → table → 회상 컷씬 → first_bread 순으로 변경
  DialoguePhase _dialoguePhase = DialoguePhase.none;

  // table.json -> 회상 컷씬 전환용 검은 화면 페이드 오버레이
  bool _showMemoryFadeOverlay = false;
  double _memoryFadeOpacity = 0.0;
  Timer? _memoryFadeTimer;

  // 채온-릴리안 첫 만남 대사(line/choice 그래프 순회, 타이핑 효과, 온도 변화) 상태 관리
  late final SceneDialogueController _sceneController;

  bool _thermometerImagesPrecached = false;

  @override
  void initState() {
    super.initState();

    _game = BakeryGame(skipChapter1Events: widget.skipChapter1Events);
    // 챕터3 재진입 모드면, 릴리안-채온 첫 만남 대사/회상 컷씬/빵 먹는 대사 단계를 전부 건너뜀
    if (widget.skipChapter1Events) {
      _dialoguePhase = DialoguePhase.kitchenApproach;
    }

    _sceneController = SceneDialogueController(
      onDialogueEnd: () {
        switch (_dialoguePhase) {
          case DialoguePhase.firstMeet:
            // 릴리안-채온 첫 만남 대화가 끝났으니 자유롭게 걸을 수 있는 구간으로 전환하고 릴리안 퇴장
            setState(() {
              _isFreeWalkPhase = true;
              _isLillianVisible = false;
              _dialoguePhase = DialoguePhase.none;
            });
            // 카메라가 채온이를 따라가도록 복귀
            _game.lillianArrivalX = null;
            _game.startCameraCatchUp();
            break;
          case DialoguePhase.table:
            // 자유이동으로 빠지지 않고, 검은 화면 페이드 전환 후 회상 컷씬(구름 미니게임)으로 전환
            _transitionToMemoryFlashback();
            break;
          case DialoguePhase.firstBread:
            // 앞치마 착용 후 주방으로 내려가는 연출 단계로 전환. 이때부터 계단 트리거가 실제로 소모되게 켜짐
            setState(() {
              _dialoguePhase = DialoguePhase.kitchenApproach;
              _isLillianVisible = false;
              _isFreeWalkPhase = true;
            });
            _game.isMovementBlocked = false;
            // kitchenApproach 단계에서만 계단 트리거가 실제로 소모되게 켜줌
            _game.isKitchenApproachActive = true;
            // 카메라가 채온이를 따라가도록 복귀
            _game.lillianArrivalX = null;
            _game.startCameraCatchUp();
            break;
          case DialoguePhase.kitchenApproach:
            // kitchenApproach 단계에서 로드되는 JSON 대사는 지금 chapter3_door.json 하나뿐이라
            // 여기로 오면 그 대사가 끝난 거임. 이동 잠금 풀어주면 나머지(계단 트리거)는 알아서 이어짐
            _game.isMovementBlocked = false;
            break;
          case DialoguePhase.none:
          case DialoguePhase.memoryFlashback:
            break;
        }
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
        setState(() {
          _isLillianWalking = false; // 도착하면 idle 모션으로 전환
          _dialoguePhase = DialoguePhase.table;
        });
        _sceneController.loadDialogue('assets/lines/chapter1/table.json');
      }
    });

    // 채온이 계단 하강 애니메이션 제어기 설정
    _chaeonStairsDescentController =
        AnimationController(vsync: this, duration: _stairsDescentDuration)
          ..addListener(() {
            setState(() {});
          });
    _chaeonStairsDescentController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToKitchenScreen();
      }
    });

    // 계단 근처 도달 시 주방으로 내려가는 연출 시작. kitchenApproach 단계가 아니면
    // (이전 단계에서 실수로 걸렸으면) 그냥 무시하고 반응 안 함
    _game.onReachStairs = () {
      if (_dialoguePhase != DialoguePhase.kitchenApproach) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerChaeonStairsDescent();
      });
    };

    // skipChapter1Events 모드에서 계단 가는 길목에 도달하면 chapter3_door.json 대사 로드.
    // isMovementBlocked/movePlayer(0)은 BakeryGame 쪽 트리거에서 이미 처리하고 넘어옴
    _game.onReachChapter3Door = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sceneController.loadDialogue(
            'assets/lines/chapter3/chapter3_door.json',
          );
        }
      });
    };

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
          _dialoguePhase = DialoguePhase.firstMeet;
        });
        // 릴리안 도착 후 첫 만남 대사 시작
        debugPrint("릴리안 도착 완료 조작 잠금 해제");
        _sceneController.loadDialogue('assets/lines/chapter1/first_meet.json');
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
              // 마을(튜토리얼)에서 빵집 문으로 다시 들어오면 새 GamePlayScreen을 만들지 않고
              // pop해서 지금 이 화면(대사/이동 진행 상태 그대로)으로 돌아오게 함
              returnToExistingGame: true,
            ),
          ),
        );
        if (!mounted) return;
        // 왼쪽 벽 트리거 좌표(size.x/2)에 그대로 멈춰있으면 복귀하자마자 onReachLeftEdge가
        // 다시 발동해버리므로, 벽에서 살짝 떨어진 곳으로 옮기고 이동 입력도 정지시켜둠
        _game.movePlayer(0);
        _game.chaeon?.position.x = 150;
        setState(() {
          _isNavigatingToTutorial = false;
          _chaeonState = 'idle';
          _isChaeonFacingRight = true;
        });
      });
    };
  }

  void _onSceneControllerChanged() {
    if (!mounted) return;
    setState(() {
      // 먹는 클로즈업 노드를 한 번이라도 지나가면 이후로는 계속 "먹은 상태"로 취급
      final String? nodeId = _sceneController.sceneNodeId;
      if (_dialoguePhase == DialoguePhase.table &&
          nodeId != null &&
          (widgets.eatingCloseupNodeIdsA.contains(nodeId) ||
              widgets.eatingCloseupNodeIdsB.contains(nodeId))) {
        _hasEatenBread = true;
      }
    });
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
      // table.json 대사 구간에서 채온이 먹는 GIF를 전체화면 클로즈업으로 보여주므로, 미리 프리캐싱
      const List<String> tableSceneAssets = [
        'assets/images/bread_plate.png',
        'assets/images/chaeon_laughing.gif',
        'assets/images/chaeon_laughing.png',
        'assets/images/chaeon_holding_bread.png',
      ];
      for (final asset in tableSceneAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // first_bread.json 특정 노드에서 잠깐 바뀌는 채온이 감정 GIF도 미리 프리캐싱.
      // beforeReveal/afterReveal 둘 다 있을 수 있어서 둘 다 챙겨줌
      for (final override in widgets.chaeonSpriteOverrides.values) {
        precacheImage(AssetImage(override.beforeReveal), context);
        final String? afterReveal = override.afterReveal;
        if (afterReveal != null) {
          precacheImage(AssetImage(afterReveal), context);
        }
      }
      // first_meet.json 특정 노드에서 잠깐 바뀌는 릴리안 스프라이트도 미리 프리캐싱
      for (final asset in widgets.lillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      // table.json 특정 노드에서 잠깐 바뀌는 릴리안 스프라이트도 미리 프리캐싱
      for (final asset in widgets.tableLillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      // first_bread.json 특정 노드에서 잠깐 바뀌는 릴리안 스프라이트도 미리 프리캐싱
      for (final asset in widgets.firstBreadLillianSpriteOverrides.values) {
        precacheImage(AssetImage(asset), context);
      }
      // 앞치마 착용 연출(kitchenApproach)에서 쓰는 채온이 스프라이트도 프리캐싱
      const List<String> apronAssets = [
        'assets/images/chaeon_apron_putting_on.gif',
        'assets/images/chaeon_apron_idle.gif',
      ];
      for (final asset in apronAssets) {
        precacheImage(AssetImage(asset), context);
      }
      // 챕터3 재진입 모드(skipChapter1Events)에서 지하 내려가기 전까지 쓰는 20% 평상복 스프라이트도 프리캐싱
      const List<String> chapter3ReentryAssets = [
        'assets/images/chaeon_20_normal.gif',
        'assets/images/chaeon_20_normal_walk.gif',
      ];
      for (final asset in chapter3ReentryAssets) {
        precacheImage(AssetImage(asset), context);
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
    _chaeonStairsDescentController.dispose();
    _memoryFadeTimer?.cancel();
    super.dispose();
  }

  // table.json 종료 -> 검은 화면 페이드인(300ms) -> 유지(400ms, 이 동안 회상 컷씬으로 전환해둠)
  // -> 페이드아웃(300ms)되며 memory_car_bumpy.gif 노출
  void _transitionToMemoryFlashback() {
    setState(() {
      _showMemoryFadeOverlay = true;
      _memoryFadeOpacity = 0.0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _memoryFadeOpacity = 1.0);
    });
    _memoryFadeTimer = Timer(_memoryFadeInDuration, () {
      if (!mounted) return;
      // 화면이 완전히 검게 덮인 상태에서 미리 전환해둬서, 화면이 열릴 때 바로 회상 컷씬이 보임
      setState(() => _dialoguePhase = DialoguePhase.memoryFlashback);
      _memoryFadeTimer = Timer(_memoryFadeHoldDuration, () {
        if (!mounted) return;
        setState(() => _memoryFadeOpacity = 0.0);
        _memoryFadeTimer = Timer(_memoryFadeOutDuration, () {
          if (!mounted) return;
          setState(() => _showMemoryFadeOverlay = false);
        });
      });
    });
  }

  // 현재 씬 노드에 맞춰 채온이 스프라이트 경로와 세로 위치 보정값을 결정.
  // first_bread.json 단계면 chaeonSpriteOverrides부터 확인하고(해당 노드 아니면 기본 idle로 복귀),
  // 그 외 단계(table.json 등)면 기존처럼 _hasEatenBread/이동 상태로 결정
  // override가 있는 노드는 bubbleRevealed(말풍선이 떴는지) 기준으로 beforeReveal/afterReveal 중 골라줌
  (String, double) _resolveChaeonSprite(String? sceneNodeId) {
    // 챕터3 재진입 모드는 kitchenApproach 단계로 시작해도 아직 앞치마 입기 전(지하 내려가기 전)
    // 상태라서, 아래 kitchenApproach 앞치마 분기보다 먼저 여기서 20% 평상복 스프라이트로 처리함
    if (widget.skipChapter1Events) {
      return (
        _chaeonState == 'walk'
            ? 'assets/images/chaeon_20_normal_walk.gif'
            : 'assets/images/chaeon_20_normal.gif',
        0,
      );
    }
    if (_dialoguePhase == DialoguePhase.firstBread) {
      final widgets.ChaeonSpriteOverride? override =
          widgets.chaeonSpriteOverrides[sceneNodeId];
      if (override != null) {
        if (_sceneController.bubbleRevealed) {
          final String? afterReveal = override.afterReveal;
          if (afterReveal != null) {
            return (afterReveal, override.afterRevealVerticalOffsetPx);
          }
          // afterReveal이 따로 없으면 기본 idle로 폴백
          return ('assets/images/chaeon_idle_right.gif', 0);
        }
        return (override.beforeReveal, override.beforeRevealVerticalOffsetPx);
      }
      return ('assets/images/chaeon_idle_right.gif', 0);
    }
    // 계단 하강 중엔 그 시점 _chaeonState(walk/idle)와 무관하게 항상 apron_idle.gif로 고정
    if (_isChaeonDescendingStairs) {
      return ('assets/images/chaeon_apron_idle.gif', 0);
    }
    // 앞치마 착용 후 주방으로 내려가는 연출 단계(kitchenApproach)에서는, walk 상태면 apron_idle.gif
    // TODO: 나중에 앞치마 입고 걷는 walk 전용 에셋 나오면 _chaeonState 보고 분기하도록 교체할 예정
    if (_dialoguePhase == DialoguePhase.kitchenApproach) {
      return (
        _chaeonState == 'walk'
            ? 'assets/images/chaeon_apron_idle.gif'
            : 'assets/images/chaeon_apron_putting_on.gif',
        0,
      );
    }
    if (_hasEatenBread) {
      return ('assets/images/chaeon_holding_bread.png', 0);
    }
    return (
      _chaeonState == 'walk'
          ? 'assets/images/chaeon_walk_right.gif'
          : 'assets/images/chaeon_idle_right.gif',
      0,
    );
  }

  // 현재 씬 노드에 맞춰 릴리안 스프라이트 경로를 결정. 노드에 expression이 있으면 그걸 쓰고,
  // 없으면 기존처럼 걷는 중인지 여부로 결정
  String _resolveLillianSprite(String? sceneNodeId) {
    final String? expressionAsset =
        _sceneController.sceneDialogue?.nodes[sceneNodeId]?.expression?.asset;
    if (expressionAsset != null) return expressionAsset;
    return _isLillianWalking
        ? 'assets/images/lillian_walk.gif'
        : 'assets/images/lillian_idle.gif';
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
    // 릴리안이 계단을 다 올라와서 채온이 앞까지 걸어오면, 그 다음 연출을 트리거
    final double chaeonX = _game.chaeon?.position.x ?? 1300.0;
    final Offset walkEnd = Offset(chaeonX + 280, 172); // 채온이 앞 280 거리

    final double climbDist = (_stairsTopPoint - _stairsOffscreenPoint).distance;
    final double walkDist = (walkEnd - _stairsTopPoint).distance;

    _lillianStairsAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: _stairsOffscreenPoint,
          end: _stairsTopPoint,
        ),
        weight: climbDist,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: _stairsTopPoint, end: walkEnd),
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

  // 채온이가 계단 근처에 도달하면 조작을 잠그고, 계단 꼭대기(_stairsTopPoint)에서
  // 화면 밖(계단 아래, _chaeonStairsDescentEnd)으로 내려가는 하강 애니메이션을 재생
  void _triggerChaeonStairsDescent() {
    _chaeonStairsDescentAnimation =
        TweenSequence<Offset>([
          TweenSequenceItem(
            tween: Tween<Offset>(
              begin: _stairsTopPoint,
              end: _chaeonStairsDescentEnd,
            ),
            weight: 1,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _chaeonStairsDescentController,
            curve: Curves.easeIn,
          ),
        );

    setState(() {
      _isFreeWalkPhase = false; // 하강 중엔 방향키도 숨김
      _isChaeonDescendingStairs = true;
    });

    _chaeonStairsDescentController.forward(from: 0);
  }

  // 하강 애니메이션이 끝나면 암전 후 주방 화면으로 전환. onReachLeftEdge에서 쓰는 것과 동일한
  // fadeThroughBlackRoute + 중복 네비게이션 방지 패턴
  void _navigateToKitchenScreen() {
    if (_isNavigatingToKitchen) return;
    _isNavigatingToKitchen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.push(
        context,
        fadeThroughBlackRoute(
          KitchenScreen(
            initialTemperature: _sceneController.temperature,
            mode: widget.skipChapter1Events
                ? KitchenScreenMode.chapter3Start
                : KitchenScreenMode.chapter1End,
          ),
        ),
      );
      if (!mounted) return;
      // 주방에서 왼쪽 끝까지 이동해 다시 계단을 올라와 돌아온 경우: 하강 연출 상태를 되돌리고,
      // 트리거 좌표에 딱 걸쳐있으면 돌아오자마자 하강 연출이 다시 발동해버리므로 살짝 떨어뜨려둠
      _game.chaeon?.position.x = kitchenStairsTriggerX - 100;
      _game.movePlayer(0);
      _game.resetStairsTrigger();
      _game.isMovementBlocked = false;
      setState(() {
        _isNavigatingToKitchen = false;
        _isChaeonDescendingStairs = false;
        _isFreeWalkPhase = true;
        _chaeonState = 'idle';
      });
    });
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
    // 계단 하강 중엔 게임 월드 절대좌표(_stairsTopPoint -> _chaeonStairsDescentEnd) 애니메이션 값을
    // 그대로 렌더링 좌표로 사용 (기존 chaeon.position.x 기반 좌표 대신)
    final Offset? chaeonStairsDescentPos = _isChaeonDescendingStairs
        ? _chaeonStairsDescentAnimation?.value
        : null;
    double renderChaeonX =
        ((chaeonStairsDescentPos?.dx ?? chaeonX) - cameraX) * zoom -
        chaeonDisplaySize / 2;

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
      lillianTopValue = rH(172);
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
    final (String chaeonSpriteAsset, double chaeonSpriteVerticalOffsetPx) =
        _resolveChaeonSprite(sceneNodeId);
    final DialogueNode? currentSceneNode =
        (sceneDialogue != null && sceneNodeId != null)
        ? sceneDialogue.nodes[sceneNodeId]
        : null;
    final DialogueNode? lastLineNode = _sceneController.lastLineNode;

    // table.json의 먹는 대사 구간에서는 채온 GIF 대신 전체화면 클로즈업을 보여줌 (분기별로 다른 에셋)
    final bool isEatingCloseupActiveA =
        _dialoguePhase == DialoguePhase.table &&
        sceneNodeId != null &&
        widgets.eatingCloseupNodeIdsA.contains(sceneNodeId);
    final bool isEatingCloseupActiveB =
        _dialoguePhase == DialoguePhase.table &&
        sceneNodeId != null &&
        widgets.eatingCloseupNodeIdsB.contains(sceneNodeId);
    final bool isEatingCloseupActive =
        isEatingCloseupActiveA || isEatingCloseupActiveB;

    // 먹는 클로즈업 중에는 채온/릴리안 스프라이트가 안 보이므로, 말풍선도 캐릭터의
    // 월드 좌표 대신 화면 중앙(클로즈업 이미지 기준)에 맞춰 표시
    final double bubbleChaeonCenterX = isEatingCloseupActive
        ? w / 2
        : chaeonCenterX;
    final double bubbleLillianCenterX = isEatingCloseupActive
        ? w / 2
        : lillianCenterX;

    // 빵 접시는 채온-릴리안 사이, 테이블 가로 중앙에 표시 (테이블 상판 바로 위)
    double breadPlateWorldX = (chaeonX + currentLillianX) / 2;
    double breadPlateDisplaySize = rW(73);
    double renderBreadPlateX =
        (breadPlateWorldX - cameraX) * zoom - breadPlateDisplaySize / 2;

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

            // 2층: 채온 GIF (table.json 먹는 구간에서는 전체화면 클로즈업으로 대체)
            if (!widget.isPrologue &&
                _game.chaeon != null &&
                _game.chaeon!.isMounted)
              if (isEatingCloseupActive)
                Positioned.fill(
                  key: const ValueKey('chaeon_eating_closeup'),
                  child: widgets.EatingCloseupOverlay(
                    onFinished: _sceneController.advanceScene,
                  ),
                )
              else if (chaeonStairsDescentPos != null)
                // 계단 하강 중: 게임 월드 절대좌표(top 기준, 릴리안 계단 등장 연출과 동일한 방식)로 배치
                Positioned(
                  key: const ValueKey('chaeon'),
                  left: renderChaeonX,
                  top: rH(chaeonStairsDescentPos.dy),
                  height: chaeonDisplaySize,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _chaeonHopOffset.value + chaeonSpriteVerticalOffsetPx,
                    ),
                    child: Transform.flip(
                      flipX: !_isChaeonFacingRight,
                      child: Image.asset(
                        chaeonSpriteAsset,
                        width: chaeonDisplaySize,
                        height: chaeonDisplaySize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  key: const ValueKey('chaeon'),
                  left: renderChaeonX,
                  bottom: rH(50), // 튜토리얼 채온이와 동일한 바닥선 기준
                  child: Transform.translate(
                    // 스프라이트별 세로 위치 보정값(chaeonSpriteVerticalOffsetPx)만큼 더해줌
                    offset: Offset(
                      0,
                      _chaeonHopOffset.value + chaeonSpriteVerticalOffsetPx,
                    ),
                    child: Transform.flip(
                      flipX: !_isChaeonFacingRight,
                      child: Image.asset(
                        chaeonSpriteAsset,
                        width: chaeonDisplaySize,
                        height: chaeonDisplaySize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

            // 3층: 릴리안 GIF (먹는 클로즈업 중에는 페이드 없이 즉시 숨김)
            if (_isLillianVisible && !isEatingCloseupActive)
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
                      _resolveLillianSprite(sceneNodeId),
                      width: lillianDisplaySize,
                      height: lillianDisplaySize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

            // 3-2층: 빵 접시. table.json 대사가 시작되는 시점부터 테이블 상판 위에 표시.
            // 먹는 클로즈업 중에는 페이드 없이 즉시 숨김. 빵을 다 먹은 뒤로는 계속 숨김
            if (_dialoguePhase == DialoguePhase.table &&
                !isEatingCloseupActive &&
                !_hasEatenBread)
              Positioned(
                key: const ValueKey('bread_plate'),
                left: renderBreadPlateX,
                bottom: rH(140), // 빵 위치
                child: Image.asset(
                  'assets/images/bread_plate.png',
                  width: breadPlateDisplaySize,
                  fit: BoxFit.contain,
                ),
              ),

            // 4층: 온도계 (먹는 클로즈업 중에는 페이드 없이 즉시 숨김)
            if (_isGuidePhaseStarted &&
                !(_isDialogueActive && _dialogueStep == 0) &&
                !isEatingCloseupActive)
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
                // 디버그: dpad 재마운트 시 이전 눌림 상태가 이어지는지 테스트하려고 단계별로
                // 완전히 다른 키를 줘서 매번 새 위젯으로 취급되게 함. 원인 아니면 나중에 되돌릴 것
                key: ValueKey('dpad_left_$_dialoguePhase'),
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
                // 디버그: dpad 재마운트 시 이전 눌림 상태가 이어지는지 테스트하려고 단계별로
                // 완전히 다른 키를 줘서 매번 새 위젯으로 취급되게 함. 원인 아니면 나중에 되돌릴 것
                key: ValueKey('dpad_right_$_dialoguePhase'),
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
            // 먹는 클로즈업(isEatingCloseupActive) 중에는 탭으로 넘기지 못하게 막음.
            // EatingCloseupOverlay가 자체 타이머(onFinished)로만 다음 노드로 넘겨야 하는데,
            // 여기 탭 레이어가 겹쳐 있으면 애니메이션이 끝나기 전에 유저가 탭해서 먼저 넘어가버림
            if (currentSceneNode != null &&
                currentSceneNode.type == 'line' &&
                !isEatingCloseupActive)
              Positioned.fill(
                key: const ValueKey('scene_bubble_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sceneController.advanceScene,
                  child: Stack(
                    children: [
                      // 대사 텍스트 없는 노드(예: 먹는 클로즈업 사이 빈 노드)는 말풍선 없이
                      // 탭으로만 다음으로 넘어감
                      // bubbleRevealed가 false면 GIF 재생 중이라는 뜻이라 말풍선을 아직 안 그림
                      if (currentSceneNode.spans.isNotEmpty &&
                          _sceneController.bubbleRevealed)
                        widgets.buildSceneBubble(
                          node: currentSceneNode,
                          rW: rW,
                          rH: rH,
                          chaeonCenterX: bubbleChaeonCenterX,
                          lillianCenterX: bubbleLillianCenterX,
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
                        chaeonCenterX: bubbleChaeonCenterX,
                        lillianCenterX: bubbleLillianCenterX,
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
            // 먹는 클로즈업 중에는 페이드 없이 즉시 숨김
            if (_isGuidePhaseStarted &&
                !_isDialogueActive &&
                !isEatingCloseupActive)
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
            // 먹는 클로즈업 중에는 페이드 없이 즉시 숨김
            if (_isGuidePhaseStarted &&
                !_isDialogueActive &&
                !isEatingCloseupActive)
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

            // 18층: 회상 컷씬(구름 드래그 미니게임 + 놀이공원 연출). 최상단에서 화면을 전부 덮음
            if (_dialoguePhase == DialoguePhase.memoryFlashback)
              Positioned.fill(
                key: const ValueKey('memory_flashback'),
                child: MemoryFlashbackScene(
                  onTemperatureIncrease: () =>
                      _sceneController.applyTemperatureEffect(1),
                  onComplete: () {
                    setState(() => _dialoguePhase = DialoguePhase.firstBread);
                    _sceneController.loadDialogue(
                      'assets/lines/chapter1/first_bread.json',
                    );
                  },
                ),
              ),

            // 19층: 앞치마 착용은 풀스크린 컷씬 없이 2층 채온이 스프라이트
            // 전환(_resolveChaeonSprite)만으로 처리함. onDialogueEnd의 firstBread 분기 참고

            // 20층: table.json -> 회상 컷씬 전환용 검은 화면 페이드. 항상 최상단
            if (_showMemoryFadeOverlay)
              Positioned.fill(
                key: const ValueKey('memory_fade_overlay'),
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _memoryFadeOpacity,
                    duration: _memoryFadeOpacity == 1.0
                        ? _memoryFadeInDuration
                        : _memoryFadeOutDuration,
                    child: Container(color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
