// lib/features/chapter1/game_play_screen.dart

import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart';
import 'package:emotional_bakery/core/widgets/dialogue_overlay.dart';
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/services/dialogue_loader.dart';

class GamePlayScreen extends StatefulWidget {
  final bool isPrologue;
  const GamePlayScreen({super.key, this.isPrologue = false});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with SingleTickerProviderStateMixin {
  final BakeryGame _game = BakeryGame();

  bool _isDialogueActive = false;
  int _dialogueStep = 0;
  List<String> _dialogueTexts = [];

  // 배경 오브젝트(박스, 잼 등) 클릭 시 뜨는 정보성 팝업 텍스트. x=650 가이드 대사와는 별개라 이동 잠금 등엔 영향 없음
  String? _interactionText;

  // 설정(옵션) 버튼을 눌렀을 때 뜨는 팝업 표시 여부
  bool _isSettingOpen = false;

  // 채온이 상태 변수
  String _chaeonState = 'idle';
  bool _isChaeonFacingRight = true; // 채온 좌우 반전용 스위치

  // 릴리안 상태 및 자동 걷기 애니메이션 변수
  late AnimationController _lillianController;
  double _lillianStartX = 1500.0; // 릴리안 시작 좌표 (빵집 우측 깊숙한 곳)
  double _lillianTargetX = 900.0; // 걸어와서 멈출 좌표 (고정값, 채온이는 x=650에서 멈춤)
  bool _isLillianWalking = false; // 릴리안이 현재 걷는 중인지 여부
  bool _isLillianVisible = false; // x=650 지점 대화가 끝나기 전에는 릴리안을 숨김

  // 왼쪽 끝에서 튜토리얼 화면으로 전환 중 중복 네비게이션 방지 플래그
  bool _isNavigatingToTutorial = false;

  // 암전(x=650 지점 대화) 한 번 시작되면 true 고정. 이때부터 온도계/뒤로가기 노출, 이동 버튼 숨김
  bool _isGuidePhaseStarted = false;

  // 릴리안 도착 후 이어지는 채온-릴리안 말풍선 대화(JSON 그래프). _sceneNodeId null이면 시작 전이거나 끝난 것
  DialogueGraph? _sceneDialogue;
  String? _sceneNodeId;

  // 대화 중 effect로 누적되는 감정 온도 (아직 UI에 반영하는 곳은 없음)
  int _temperature = 0;

  // 말풍선 타이핑 효과: 현재 line 노드에서 몇 글자까지 보여줬는지
  Timer? _typingTimer;
  int _typedCharCount = 0;
  static const Duration _typingInterval = Duration(milliseconds: 35);

  @override
  void initState() {
    super.initState();

    // 릴리안 걷기 애니메이션 제어기 설정
    // duration은 _triggerLillianWalk()에서 채온이 이동 속도에 맞춰 매번 재계산됨
    _lillianController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            setState(() {}); // 애니메이션 프레임마다 화면을 다시 그려 릴리안 이동 반영
          });

    // 릴리안 도착 시 실행될 리스너
    _lillianController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isLillianWalking = false;
          _game.isMovementBlocked = false;
        });
        print("릴리안 도착 완료 조작 잠금 해제");
        _startFirstMeetDialogue();
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

    // 배경 오브젝트 클릭 시 정보성 팝업 텍스트 표시.
    // Flame 탭 콜백이 Flutter 빌드 사이클이랑 안 맞을 수 있어서 addPostFrameCallback으로 감쌈
    _game.onInteract = (text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _interactionText = text);
      });
    };

    // 매 프레임(BakeryGame.update()) 호출됨. 여기서 바로 setState 하면 "called during build" 예외 나서 addPostFrameCallback으로 감쌈
    _game.onGameUpdate = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    };

    // 왼쪽 끝까지 간 뒤 계속 왼쪽으로 가려 하면 마을 배경(튜토리얼 안내 없이 바로 인터랙티브)으로 전환
    _game.onReachLeftEdge = () {
      if (widget.isPrologue || _isNavigatingToTutorial) return;
      _isNavigatingToTutorial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            // 빵집으로 들어갈 때와 같은 위치(빵집 문 앞)에서, 마을 쪽을 보며 다시 등장
            builder: (context) => const TutorialScreen(
              initialStep: 2,
              initialPlayerX: 950,
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

  @override
  void dispose() {
    _lillianController.dispose(); // 메모리 누수 방지용
    _typingTimer?.cancel();
    super.dispose();
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

    _lillianController.forward(from: 0.0); // 걷기 애니메이션 스타트!
  }

  // 암전 레이어를 탭했을 때와 동일한 "다음 대사로 넘기기" 로직.
  // 암전 위로 올라온 뒤로가기 버튼도 이 로직을 그대로 재사용함
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

  // 릴리안이 도착하면 이어서 재생되는 채온-릴리안 말풍선 대화(JSON 그래프) 로드 & 시작
  Future<void> _startFirstMeetDialogue() async {
    final graph = await DialogueLoader.loadDialogue(
      'assets/lines/chapter1/first_meet.json',
    );
    if (!mounted) return;
    setState(() {
      _sceneDialogue = graph;
      _enterSceneNode(graph.start);
    });
  }

  // 노드 하나로 진입. line 노드면 온도 효과 바로 적용하고 타이핑 시작, next 없거나 이상한 노드면 대화 종료
  void _enterSceneNode(String? nodeId) {
    _typingTimer?.cancel();
    final graph = _sceneDialogue;
    if (nodeId == null || graph == null || !graph.nodes.containsKey(nodeId)) {
      _sceneNodeId = null;
      _sceneDialogue = null;
      _typedCharCount = 0;
      return;
    }
    _sceneNodeId = nodeId;
    final node = graph.nodes[nodeId]!;
    if (node.type == 'line') {
      _temperature += node.temperatureEffect;
      _startTypingEffect(node);
    } else {
      _typedCharCount = 0;
    }
  }

  // 대사를 한 글자씩 순차적으로 드러내는 타이핑 효과 시작
  void _startTypingEffect(DialogueNode node) {
    final int fullLength = node.spans.fold(0, (sum, s) => sum + s.text.length);
    _typedCharCount = 0;
    if (fullLength == 0) return;
    _typingTimer = Timer.periodic(_typingInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _typedCharCount++;
        if (_typedCharCount >= fullLength) {
          timer.cancel();
        }
      });
    });
  }

  // node.spans를 앞에서부터 charCount 글자만 남도록 잘라서 반환. 스타일은 그대로 유지
  List<DialogueSpan> _truncateSpans(List<DialogueSpan> spans, int charCount) {
    final List<DialogueSpan> result = [];
    int remaining = charCount;
    for (final span in spans) {
      if (remaining <= 0) break;
      if (span.text.length <= remaining) {
        result.add(span);
        remaining -= span.text.length;
      } else {
        result.add(
          DialogueSpan(
            text: span.text.substring(0, remaining),
            color: span.color,
            bold: span.bold,
          ),
        );
        remaining = 0;
      }
    }
    return result;
  }

  // 말풍선 탭하면 다음 노드로. 타이핑 중이면 다음으로 안 넘기고 텍스트 다 보여주기만 함(VN 탭 동작)
  void _advanceScene() {
    final graph = _sceneDialogue;
    final node = (graph != null && _sceneNodeId != null)
        ? graph.nodes[_sceneNodeId]
        : null;
    if (node == null || node.type != 'line') return;

    final int fullLength = node.spans.fold(0, (sum, s) => sum + s.text.length);
    if (_typedCharCount < fullLength) {
      _typingTimer?.cancel();
      setState(() => _typedCharCount = fullLength);
      return;
    }

    setState(() => _enterSceneNode(node.next));
  }

  // 선택지 하나를 골랐을 때 그 선택지의 next로 이동
  void _chooseSceneOption(DialogueOption option) {
    setState(() => _enterSceneNode(option.next));
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // 오브젝트 클릭 정보 팝업은 이동 가능한 상태에서만 허용 (5층/6층 dpad 노출 조건과 동일)
    _game.canInteract = !widget.isPrologue && !_isGuidePhaseStarted;

    // 실시간 카메라 스크롤 값 계산 (position은 centerLeft 앵커 기준 "화면 왼쪽 끝 월드 좌표")
    double cameraX = _game.camera.isMounted
        ? _game.camera.viewfinder.position.x
        : 0.0;

    // 배경이 세로로 항상 꽉 차도록 하는 카메라 줌 (BakeryGame.update()의 계산과 동일해야 함)
    double zoom = h / _game.mapHeight;

    // 채온이 렌더링 좌표 계산
    double chaeonX = (_game.chaeon != null && _game.chaeon!.isMounted)
        ? _game.chaeon!.position.x
        : 0.0;

    // Chaeon anchor가 bottomCenter라 position.x는 중심 좌표, Positioned.left는 좌측 끝 기준이라
    // 표시 너비 절반만큼 보정 필요 (안 해주면 채온이가 오른쪽으로 치우쳐 보임)
    double chaeonDisplaySize = 172 * zoom; // Chaeon 컴포넌트의 size(172)와 동일 스케일
    double renderChaeonX = (chaeonX - cameraX) * zoom - chaeonDisplaySize / 2;

    // 릴리안 렌더링 좌표 계산
    double currentLillianX = Tween<double>(
      begin: _lillianStartX,
      end: _lillianTargetX,
    ).evaluate(_lillianController);
    // 채온이랑 똑같이 중심 기준 보정 필요 (안 하면 릴리안이 오른쪽으로 밀려 그려짐)
    double lillianDisplaySize = 174 * zoom;
    double renderLillianX =
        (currentLillianX - cameraX) * zoom - lillianDisplaySize / 2;

    // 채온-릴리안 말풍선 가로 위치 계산용: 각 캐릭터의 화면상 가로 중심
    double chaeonCenterX = renderChaeonX + chaeonDisplaySize / 2;
    double lillianCenterX = renderLillianX + lillianDisplaySize / 2;

    final DialogueNode? currentSceneNode =
        (_sceneDialogue != null && _sceneNodeId != null)
        ? _sceneDialogue!.nodes[_sceneNodeId]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // 1층: 게임 엔진 구역
            // Stack 자식들에 Key 안 주면 조건부 위젯 사라질 때 다른 위젯이 그 자리를 이어받아서
            // 눌려있던 포인터까지 이어받는 버그 있었음(이동 버튼 누른 채로 대화 트리거 발동하는 경우 등). 그래서 다 Key 부여함
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
            // 프롤로그(내레이션 이미지) 중에는 채온이가 겹쳐 보이면 안 되므로 숨김
            if (!widget.isPrologue &&
                _game.chaeon != null &&
                _game.chaeon!.isMounted)
              Positioned(
                key: const ValueKey('chaeon'),
                left: renderChaeonX,
                bottom: rH(50), // 튜토리얼 채온이와 동일한 바닥선 기준
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

            // 3층: 릴리안 GIF (릴리안이 등장하는 시점인 isLillianVisible일 때만 노출)
            if (_isLillianVisible)
              Positioned(
                key: const ValueKey('lillian'),
                left: renderLillianX,
                top: rH(163), // 채온이와 완벽하게 발밑 일치
                bottom: rH(48),
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

            // 4층: 온도계 ("암전 아래" 슬롯)
            // step 0(온도 설명) 중엔 온도계가 암전 위로 올라가야 하므로 이 슬롯엔 안 그림
            if (_isGuidePhaseStarted &&
                !(_isDialogueActive && _dialogueStep == 0))
              _buildThermometer(key: 'thermometer_below', rW: rW, rH: rH),

            // 4-2층: 설정 버튼. 뒤로가기랑 달리 암전 중에도 계속 이 슬롯(암전 아래)에만 그려짐
            if (_isGuidePhaseStarted)
              _buildSettingButton(key: 'setting', rW: rW, rH: rH),

            // 4-3층: 뒤로가기 버튼 ("암전 아래" 슬롯)
            // step 1(뒤로가기 설명) 중엔 버튼이 암전 위로 올라가야 하므로 이 슬롯엔 안 그림
            if (_isGuidePhaseStarted &&
                !(_isDialogueActive && _dialogueStep != 0))
              _buildBackButton(key: 'back_below', rW: rW, rH: rH),

            // 5층: 가상 패드 왼쪽 이동 버튼 영역
            // 암전(x=650 지점 대화)이 시작되면 버튼을 숨겨 이동을 막음
            if (!widget.isPrologue && !_isGuidePhaseStarted)
              Positioned(
                key: const ValueKey('dpad_left'),
                left: rW(686),
                bottom: rH(20),
                child: GestureDetector(
                  onTapDown: (_) {
                    _game.movePlayer(-1);
                    setState(() {
                      _chaeonState = 'walk';
                      _isChaeonFacingRight = false;
                    });
                  },
                  onTapUp: (_) {
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
                  child: Container(
                    width: rW(64),
                    height: rH(64),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/btn_left.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

            // 6층: 가상 패드 오른쪽 이동 버튼 영역
            // 암전(x=650 지점 대화)이 시작되면 버튼을 숨겨 이동을 막음
            if (!widget.isPrologue && !_isGuidePhaseStarted)
              Positioned(
                key: const ValueKey('dpad_right'),
                left: rW(778),
                bottom: rH(20),
                child: GestureDetector(
                  onTapDown: (_) {
                    _game.movePlayer(1);
                    setState(() {
                      _chaeonState = 'walk';
                      _isChaeonFacingRight = true;
                    });
                  },
                  onTapUp: (_) {
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
                  child: Container(
                    width: rW(64),
                    height: rH(64),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/btn_right.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
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

            // 8층: 온도계 ("암전 위" 슬롯, step 0일 때만 여기서 그려짐)
            if (_isDialogueActive && _dialogueStep == 0)
              _buildThermometer(key: 'thermometer_above', rW: rW, rH: rH),

            // 8-2층: 뒤로가기 버튼 ("암전 위" 슬롯, step 1일 때만 여기서 그려짐)
            // 아직 클릭 기능 없어서 탭하면 아래 암전 레이어가 받아서 대사 넘어감 (설정 버튼은 계속 4-2층에만 있음)
            if (_isDialogueActive && _dialogueStep != 0)
              _buildBackButton(key: 'back_above', rW: rW, rH: rH),

            // 9층: x=650 지점 가이드 대사창
            // step 0에서는 온도계 아래, step 1(이후)에서는 뒤로가기 버튼 아래에 위치
            if (_isDialogueActive && _dialogueTexts.isNotEmpty)
              _buildCustomDialogue(
                key: 'dialogue_box',
                step: _dialogueStep,
                rW: rW,
                rH: rH,
              ),

            // 10층: 오브젝트 클릭 정보성 팝업 - 화면 아무 곳이나 탭하면 닫힘
            // 이동 버튼보다 위라 탭을 먼저 가로챔 (팝업 떠 있으면 이동 버튼 눌러도 팝업부터 닫힘)
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
              _buildInteractionBox(text: _interactionText!, rW: rW, rH: rH),

            // 12층: 설정(옵션) 팝업 - 검은 반투명(50%) 배경, 80%x80% 박스 안에 원본 비율(650:343) 유지해서 표시
            // 배경 탭해도 안 닫히고 우측 상단 X 눌러야 닫힘
            if (_isSettingOpen)
              Builder(
                builder: (context) {
                  double popupW = w * 0.8;
                  double popupH = h * 0.8;

                  // 80%x80% 박스 안에서 원본 비율(650:343) 유지하며 최대로, 남는 여백은 레터박스
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

            // 13층: 채온-릴리안 첫 만남 말풍선 대화 (line 노드). 화면 탭하면 다음 노드로
            if (currentSceneNode != null && currentSceneNode.type == 'line')
              Positioned.fill(
                key: const ValueKey('scene_bubble_layer'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _advanceScene,
                  child: Stack(
                    children: [
                      _buildSceneBubble(
                        node: currentSceneNode,
                        rW: rW,
                        rH: rH,
                        chaeonCenterX: chaeonCenterX,
                        lillianCenterX: lillianCenterX,
                      ),
                    ],
                  ),
                ),
              ),

            // 14층: 선택지(choice 노드) - choice_box 이미지가 옵션 개수만큼 표시됨
            if (currentSceneNode != null && currentSceneNode.type == 'choice')
              Positioned.fill(
                key: const ValueKey('scene_choice_layer'),
                child: _buildSceneChoices(
                  node: currentSceneNode,
                  rW: rW,
                  rH: rH,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 배경 오브젝트 클릭 시 뜨는 정보성 팝업 박스. 가이드 대사창이랑 같은 9-slice 스타일인데 step 분기 없이 중앙 고정
  Widget _buildInteractionBox({
    required String text,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    return Align(
      key: const ValueKey('interaction_box'),
      alignment: const Alignment(0, 0.2),
      child: IntrinsicWidth(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: rW(20), vertical: rH(15)),
          constraints: BoxConstraints(
            minWidth: rW(180),
            maxWidth: rW(500),
            minHeight: rH(70),
          ),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/tutorial_dialogue_box.png'),
              fit: BoxFit.fill,
              centerSlice: Rect.fromLTRB(5, 5, 1114, 280),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(rW(20), 0, rW(20), 0),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF5A3E2B),
                    fontSize: rW(13),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SCDream',
                  ),
                ),
              ),
              Positioned(
                right: rW(0),
                bottom: rH(7),
                child: Image.asset(
                  'assets/images/tutorial_arrow.png',
                  width: rW(12),
                  height: rH(10),
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 온도계 위젯 (암전 레이어 위/아래 두 슬롯에서 재사용). key로 두 슬롯 구분함
  Widget _buildThermometer({
    required String key,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    return Positioned(
      key: ValueKey(key),
      left: rW(7),
      top: rH(15),
      child: Image.asset(
        'assets/images/main_thermometer_ex.png',
        width: rW(422),
        fit: BoxFit.contain,
      ),
    );
  }

  // 뒤로가기 버튼 (암전 레이어 위/아래 두 슬롯에서 재사용). 나중에 구현 예정이라 지금은 이미지만 표시
  Widget _buildBackButton({
    required String key,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    return Positioned(
      key: ValueKey(key),
      left: rW(714),
      top: rH(15),
      child: Image.asset(
        'assets/images/main_back_btn.png',
        width: rW(54),
        height: rH(54),
        fit: BoxFit.contain,
      ),
    );
  }

  // 설정(메뉴) 버튼. 뒤로가기 버튼과 달리 암전 중에도 항상 암전 아래에만 그려짐
  Widget _buildSettingButton({
    required String key,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    return Positioned(
      key: ValueKey(key),
      left: rW(788), // 뒤로가기 버튼(714) + 너비(54) + 간격(20)
      top: rH(15),
      child: GestureDetector(
        onTap: () => setState(() => _isSettingOpen = true),
        child: Image.asset(
          'assets/images/main_setting_btn.png',
          width: rW(54),
          height: rH(54),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // 커스텀 대사창 레이아웃 빌더 (기존 동일)
  Widget _buildCustomDialogue({
    required String key,
    required int step,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    List<TextSpan> spans = [];
    if (step == 0) {
      spans = [
        const TextSpan(text: "지금부터 감정의 온도를 확인할 수 있습니다.\n"),
        const TextSpan(
          text: "당신의 선택에 따라 ",
          style: TextStyle(
            color: Color(0xFFFF7F27),
            fontWeight: FontWeight.w600,
          ),
        ),
        const TextSpan(text: "감정의 온도는 오를수도, 내려갈 수도 있습니다."),
      ];
    } else {
      spans = [
        const TextSpan(text: "뒤로가기 버튼을 통해 대화를 뒤로 돌릴 수 있습니다.\n단, 당신의 "),
        const TextSpan(
          text: "선택은 돌릴 수 없습니다.",
          style: TextStyle(
            color: Color(0xFFFF7F27),
            fontWeight: FontWeight.w600,
          ),
        ),
      ];
    }

    // 튜토리얼 _buildDialogueBox랑 동일한 박스 설정. step 0은 온도계 아래, step 1은 뒤로가기/설정 버튼 아래에 위치
    return Positioned(
      key: ValueKey(key),
      left: step == 0 ? rW(26) : null,
      right: step == 0 ? null : rW(32),
      top: rH(75),
      child: IntrinsicWidth(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: rW(20), vertical: rH(15)),
          constraints: BoxConstraints(
            minWidth: rW(180),
            maxWidth: rW(500),
            minHeight: rH(70),
          ),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/tutorial_dialogue_box.png'),
              fit: BoxFit.fill,
              centerSlice: Rect.fromLTRB(5, 5, 1114, 280),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(rW(20), 0, rW(20), 0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: const Color(0xFF5A3E2B),
                      fontSize: rW(13),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SCDream',
                    ),
                    children: spans,
                  ),
                ),
              ),
              Positioned(
                right: rW(0),
                bottom: rH(7),
                child: Image.asset(
                  'assets/images/tutorial_arrow.png',
                  width: rW(12),
                  height: rH(10),
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // main_dialogue_box_1~9.png의 원본 가로 크기(px). 전부 높이는 60으로 고정.
  static const List<double> _dialogueBoxWidths = [
    107,
    147,
    188,
    232,
    274,
    317,
    361,
    404,
    451,
  ];

  // 채온-릴리안 말풍선. 대사 길이에 맞는 가장 작은 이미지 골라서 top 100, 말하는 캐릭터 중심에 표시. 채온이면 좌우 반전.
  Widget _buildSceneBubble({
    required DialogueNode node,
    required double Function(double) rW,
    required double Function(double) rH,
    required double chaeonCenterX,
    required double lillianCenterX,
  }) {
    final bool isChaeon = node.speaker == 'chaeon';
    final double centerX = isChaeon ? chaeonCenterX : lillianCenterX;

    final TextStyle baseStyle = TextStyle(
      color: const Color(0xFF5A3E2B),
      fontSize: rW(13),
      height: 1.1,
      fontWeight: FontWeight.w500,
      fontFamily: 'SCDream',
    );

    InlineSpan spanToInline(DialogueSpan s) => TextSpan(
      text: s.text,
      style: baseStyle.copyWith(
        color: s.color ?? baseStyle.color,
        fontWeight: s.bold ? FontWeight.w700 : baseStyle.fontWeight,
      ),
    );

    // 말풍선 크기는 전체 대사 기준으로 고정(타이핑 도중 박스 크기가 흔들리지 않게)
    final List<InlineSpan> fullSpans = node.spans.map(spanToInline).toList();
    final TextPainter tp = TextPainter(
      text: TextSpan(children: fullSpans),
      textDirection: TextDirection.ltr,
    )..layout();

    // 실제로 그리는 텍스트는 타이핑 진행도(_typedCharCount)만큼만 잘라서 표시
    final List<InlineSpan> visibleSpans = _truncateSpans(
      node.spans,
      _typedCharCount,
    ).map(spanToInline).toList();

    // 여백 뺀 안쪽 공간에 텍스트 들어가는 가장 작은 말풍선 선택, 안 들어가면 제일 큰 걸로
    const double nativeHorizontalPadding = 24;
    int boxIndex = _dialogueBoxWidths.length;
    for (int i = 0; i < _dialogueBoxWidths.length; i++) {
      double boxWidthPx = rW(_dialogueBoxWidths[i]);
      double availableWidth = boxWidthPx - rW(nativeHorizontalPadding * 2);
      if (tp.width <= availableWidth) {
        boxIndex = i + 1;
        break;
      }
    }

    final double bubbleWidth = rW(_dialogueBoxWidths[boxIndex - 1]);
    final double bubbleHeight = rH(60); // 말풍선은 높이 60 고정

    Widget bubbleImage = Image.asset(
      'assets/images/main_dialogue_box_$boxIndex.png',
      width: bubbleWidth,
      height: bubbleHeight,
      fit: BoxFit.fill,
    );
    if (isChaeon) {
      bubbleImage = Transform.flip(flipX: true, child: bubbleImage);
    }

    return Positioned(
      key: ValueKey('scene_bubble_${node.id}'),
      left: centerX - bubbleWidth / 2,
      top: rH(100),
      width: bubbleWidth,
      height: bubbleHeight,
      child: Stack(
        children: [
          bubbleImage,
          // 대사 텍스트: 말풍선 기준 bottom 24, 가로 가운데 정렬
          Positioned(
            left: rW(12),
            right: rW(12),
            bottom: rH(28),
            child: RichText(
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(children: visibleSpans),
            ),
          ),
        ],
      ),
    );
  }

  // 선택지(choice) 화면. 검은 반투명(50%) 배경 위에 choice_box를 옵션 개수만큼 가로로 나열, 하단(35)에 표시
  Widget _buildSceneChoices({
    required DialogueNode node,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    const double nativeW = 1264;
    const double nativeH = 240;
    final double boxHeight = rH(60);
    final double boxWidth = boxHeight * (nativeW / nativeH);
    final double gap = rW(16);

    return Stack(
      key: ValueKey('scene_choices_${node.id}'),
      children: [
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.5))),
        Positioned(
          left: 0,
          right: 0,
          bottom: rH(35),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < node.options.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                    child: GestureDetector(
                      onTap: () => _chooseSceneOption(node.options[i]),
                      child: SizedBox(
                        width: boxWidth,
                        height: boxHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/images/choice_box.png',
                              width: boxWidth,
                              height: boxHeight,
                              fit: BoxFit.fill,
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: rW(24)),
                              child: Text(
                                node.options[i].text,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: rW(14),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'SCDream',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
