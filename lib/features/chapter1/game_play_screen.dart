// lib/features/chapter1/game_play_screen.dart

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/features/chapter1/bakery_game.dart';
import 'package:emotional_bakery/core/widgets/dialogue_overlay.dart';

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

  // 채온이 상태 변수
  String _chaeonState = 'idle';
  bool _isChaeonFacingRight = true; // 채온 좌우 반전용 스위치

  // 릴리안 상태 및 자동 걷기 애니메이션 변수
  late AnimationController _lillianController;
  double _lillianStartX = 1200.0; // 릴리안 시작 좌표 (빵집 우측 깊숙한 곳)
  double _lillianTargetX = 1200.0; // 걸어와서 멈출 좌표 (채온이 앞)
  bool _isLillianWalking = false; // 릴리안이 현재 걷는 중인지 여부
  bool _isLillianVisible = false; // 30% 지점 대화가 끝나기 전에는 릴리안을 숨김

  @override
  void initState() {
    super.initState();

    // 릴리안 걷기 애니메이션 제어기 설정 (3초 동안 스무스하게 걸어옴)
    _lillianController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
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
      }
    });

    _game.onShowDialogue = (textLines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isDialogueActive = true;
            _dialogueStep = 0;
            _dialogueTexts = textLines;
          });
        }
      });
    };

    _game.onGameUpdate = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    };
  }

  @override
  void dispose() {
    _lillianController.dispose(); // 메모리 누수 방지용
    super.dispose();
  }

  void _triggerLillianWalk() {
    double chaeonX = (_game.chaeon != null && _game.chaeon!.isMounted)
        ? _game.chaeon!.position.x
        : 200.0;

    setState(() {
      _isDialogueActive = false; // 대화창 끄기
      _isLillianVisible = true; // 대화가 끝났으니 이제부터 릴리안 등장
      _isLillianWalking = true; // 릴리안 걷기 상태 돌입

      // 채온이 앞 120px 지점까지 걸어오도록 타겟 설정
      _lillianTargetX = chaeonX + 120.0;
    });

    _lillianController.forward(from: 0.0); // 걷기 애니메이션 스타트!
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // 실시간 카메라 스크롤 값 계산
    // camera.viewfinder.position은 "뷰포트 중앙에 오는 월드 좌표"이므로
    // 화면 좌측 기준 좌표로 바꾸려면 뷰포트 절반 너비를 다시 더해줘야 함
    double cameraX = _game.camera.isMounted
        ? _game.camera.viewfinder.position.x
        : 0.0;

    // 카메라가 이제 마스터 해상도 고정 좌표계를 쓰므로, 화면 절반은 항상 874/2로 고정
    const double masterHalfWidth = 437.0;

    // 채온이 렌더링 좌표 계산
    double chaeonX = (_game.chaeon != null && _game.chaeon!.isMounted)
        ? _game.chaeon!.position.x
        : 0.0;

    // 마스터 좌표계 오프셋을 계산한 뒤, rW로 실제 화면 픽셀로 변환
    double renderChaeonX = rW(chaeonX - cameraX + masterHalfWidth);

    // 릴리안 렌더링 좌표 계산
    double currentLillianX = Tween<double>(
      begin: _lillianStartX,
      end: _lillianTargetX,
    ).evaluate(_lillianController);
    double renderLillianX = rW(currentLillianX - cameraX + masterHalfWidth);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 874 / 402,
          child: Stack(
            children: [
              // 1층: 게임 엔진 구역
              Positioned.fill(
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
                  left: renderChaeonX,
                  top: rH(265), // 높이 비율
                  child: Transform.flip(
                    flipX: !_isChaeonFacingRight,
                    child: Image.asset(
                      _chaeonState == 'walk'
                          ? 'assets/images/chaeon_walk_right.gif'
                          : 'assets/images/chaeon_idle_right.gif',
                      width: rW(75),
                      height: rH(75),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              // 3층:릴리안 GIF
              if (!widget.isPrologue && _isLillianVisible)
                Positioned(
                  left: renderLillianX,
                  top: rH(265), // 채온이랑 발 높이 일치
                  child: Transform.flip(
                    flipX: _isLillianWalking, // 반전
                    child: Image.asset(
                      _isLillianWalking
                          ? 'assets/images/lillian_walk.gif'
                          : 'assets/images/lillian_idle.gif',
                      width: rW(75),
                      height: rH(75),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              // 4층: 암전 상태일 때만 온도계 & 뒤로가기 버튼 노출
              if (_isDialogueActive) ...[
                Positioned(
                  left: rW(20),
                  top: rH(15),
                  child: Image.asset(
                    'assets/images/main_thermometer_ex.png',
                    width: rW(380),
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: rW(650),
                  top: rH(15),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Image.asset(
                          'assets/images/main_back_btn.png',
                          width: rW(45),
                          height: rH(45),
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: rW(10)),
                      GestureDetector(
                        onTap: () => print("옵션 클릭!"),
                        child: Image.asset(
                          'assets/images/main_setting_btn.png',
                          width: rW(45),
                          height: rH(45),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 5층: 가상 패드 왼쪽 이동 버튼 영역
              if (!widget.isPrologue)
                Positioned(
                  left: rW(650),
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
                      setState(() => _chaeonState = 'idle');
                    },
                    child: Container(
                      width: rW(60),
                      height: rH(60),
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
              if (!widget.isPrologue)
                Positioned(
                  left: rW(730),
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
                      setState(() => _chaeonState = 'idle');
                    },
                    child: Container(
                      width: rW(60),
                      height: rH(60),
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
                  child: IgnorePointer(
                    ignoring: false,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_dialogueStep < _dialogueTexts.length - 1) {
                            _dialogueStep++;
                          } else {
                            // 대화창이 모두 끝나면 릴리안 걸어오기
                            _triggerLillianWalk();
                          }
                        });
                      },
                      child: Container(color: Colors.black.withOpacity(0.55)),
                    ),
                  ),
                ),

              // 8층: 30% 지점 가이드 대사창
              if (_isDialogueActive && _dialogueTexts.isNotEmpty)
                _buildCustomDialogue(step: _dialogueStep, rW: rW, rH: rH),
            ],
          ),
        ),
      ),
    );
  }

  // 커스텀 대사창 레이아웃 빌더 (기존 동일)
  Widget _buildCustomDialogue({
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
            fontWeight: FontWeight.bold,
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
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    }

    return Align(
      alignment: const Alignment(-0.6, -0.15),
      child: Container(
        width: rW(480),
        height: rH(105),
        padding: EdgeInsets.symmetric(horizontal: rW(25), vertical: rH(15)),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/tutorial_dialogue_box.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: const Color(0xFF5A3E2B),
                    fontSize: rW(15),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                  children: spans,
                ),
              ),
            ),
            Positioned(
              right: rW(5),
              bottom: rH(5),
              child: Image.asset(
                'assets/images/tutorial_arrow.png',
                width: rW(12),
                height: rH(12),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
