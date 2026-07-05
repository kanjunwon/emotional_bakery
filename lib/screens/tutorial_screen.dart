// lib/screens/tutorial_screen.dart

import 'package:flutter/material.dart';
import 'dart:async'; // 연속 이동 (화살표 꾹 누르기)

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _tutorialStep = 0;

  // 월드 맵 전체 가로 길이 (전체 단일 이미지 가로 스케일 기준)
  final double _mapWidth = 1352;
  double _playerX = 150; // 캐릭터 시작 위치 (뒷골목 구역)
  bool _isPlayerInitialized = false;
  String? _interactionText;

  // 연속 이동 타이머 및 캐릭터 상태 관리 변수
  Timer? _moveTimer;
  String _currentAction = 'idle';
  bool _isLookingLeft = true; // 왼쪽인지 확인 여부

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    if (!_isPlayerInitialized) {
      _playerX = rW(445);
      _isPlayerInitialized = true;
    }

    // 캐릭터가 화면 중심을 넘어설 때 배경을 반대 방향으로 밀어주는 카메라 오프셋 계산
    double screenWidth = w;
    double cameraX = (_playerX - rW(80)).clamp(
      0.0,
      rW(_mapWidth) - screenWidth,
    );

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_tutorialStep < 2) {
            setState(() {
              _tutorialStep++;
            });
          } else if (_interactionText != null) {
            setState(() {
              _interactionText = null;
            });
          }
        },
        child: Container(
          width: w,
          height: h,
          color: Colors.black,
          child: Stack(
            children: [
              // --------------------------------------------------------
              // 1층: 카메라 오프셋의 영향을 받는 인게임 월드 레이어 (배경, 오브젝트, 캐릭터)
              // --------------------------------------------------------
              Positioned(
                left: -cameraX,
                top: 0,
                width: rW(_mapWidth),
                height: h,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      width: rW(_mapWidth),
                      height: rH(699),
                      child: Image.asset(
                        'assets/images/tutorial_bg_full.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 1번 집 상호작용 구역
                    Positioned(
                      left: rW(50),
                      top: rH(60),
                      width: rW(120),
                      height: rH(240),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText =
                                  "클로에의 집이다. \n 지금은 아무도 없는 거 같다. ⌵";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 2번 집 상호작용 구역
                    Positioned(
                      left: rW(200),
                      top: rH(60),
                      width: rW(120),
                      height: rH(240),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText =
                                  "피터의 집이다. \n 예전에 한 번 들어가 본 적이 있다. ⏷";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 3번 집 상호작용 구역
                    Positioned(
                      left: rW(400),
                      top: rH(80),
                      width: rW(140),
                      height: rH(220),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText =
                                  "소피아의 집이다. \n 소피아는 나에게 항상 친절하다. ▼"; // 이 삼각형으로 결정. but, 폰트 크기 줄이기.
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 4번 집 상호작용 구역
                    Positioned(
                      left: rW(600),
                      top: rH(50),
                      width: rW(110),
                      height: rH(250),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText =
                                  "알렉스 씨의 집이다. \n 들어가면 혼날 거 같다. ▾";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 우측 목적지 (빛나는 빵집 건물) 터치 이벤트 구역 (메인 거리 끝자락)
                    Positioned(
                      left: rW(1000),
                      top: rH(40),
                      width: rW(220),
                      height: rH(260),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            if (_playerX >= rW(950)) {
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                _interactionText =
                                    "아직 빵집에 들어가기엔 \n 거리가 먼 거 같다.";
                              });
                            }
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 주인공 캐릭터 (채온) 레이어
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 100),
                      left: _playerX,
                      bottom: rH(50),
                      child: Transform.flip(
                        flipX: _isLookingLeft, // true일 때 이미지 반전
                        child: Image.asset(
                          // 오른쪽 에셋 2개만 가지고 walk와 idle을 스위칭함
                          _currentAction == 'walk'
                              ? 'assets/images/chaeon_walk_right.gif'
                              : 'assets/images/chaeon_idle_right.gif',
                          width: rW(172),
                          height: rH(172),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --------------------------------------------------------
              // 2층: 가상 패드 및 유동 대사창 UI 레이어
              // --------------------------------------------------------

              // 하단 가상 패드 (방향키 컨트롤러) 구역
              Positioned(
                right: rW(20),
                bottom: rH(20),
                child: Row(
                  children: [
                    // 왼쪽 이동 버튼
                    _buildDpadButton(
                      imagePath: 'assets/images/btn_left.png',
                      onTapDown: () {
                        if (_tutorialStep == 2) {
                          _moveTimer?.cancel();
                          setState(() {
                            _currentAction = 'walk';
                            _isLookingLeft = true;
                          });
                          _moveTimer = Timer.periodic(
                            const Duration(milliseconds: 40),
                            (timer) {
                              setState(() {
                                if (_playerX > rW(30)) _playerX -= rW(12);
                              });
                            },
                          );
                        }
                      },
                      onTapUp: () {
                        _moveTimer?.cancel();
                        setState(() {
                          _currentAction = 'idle';
                          _isLookingLeft = true;
                        });
                      },
                      rW: rW,
                      rH: rH,
                    ),
                    SizedBox(width: rW(15)),
                    // 오른쪽 이동 버튼
                    _buildDpadButton(
                      imagePath: 'assets/images/btn_right.png',
                      onTapDown: () {
                        if (_tutorialStep == 2) {
                          _moveTimer?.cancel();
                          setState(() {
                            _currentAction = 'walk';
                            _isLookingLeft = false;
                          });
                          _moveTimer = Timer.periodic(
                            const Duration(milliseconds: 40),
                            (timer) {
                              setState(() {
                                if (_playerX < rW(_mapWidth - 100))
                                  _playerX += rW(12);
                              });
                            },
                          );
                        }
                      },
                      onTapUp: () {
                        _moveTimer?.cancel();
                        // 손을 떼면 idle 상태로 돌아가되 오른쪽 방향 유지
                        setState(() {
                          _currentAction = 'idle';
                          _isLookingLeft = false;
                        });
                      },
                      rW: rW,
                      rH: rH,
                    ),
                  ],
                ),
              ),

              // 메인 가이드 대사창 (Step 0, 1 시점 노출)
              if (_tutorialStep < 2)
                _buildDialogueBox(
                  textWidget: Text.rich(
                    TextSpan(
                      children: _tutorialStep == 0
                          ? [
                              const TextSpan(
                                text: "화면을 클릭하면 다음 화면으로 넘어갑니다.\n물건이나 건물을 ",
                              ),
                              const TextSpan(
                                text: "클릭할 시",
                                style: TextStyle(
                                  color: Color(0xFFD2691E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ", 정보를 얻을 수 있습니다."),
                            ]
                          : [
                              const TextSpan(
                                text:
                                    "왼쪽 화살표를 클릭하면 캐릭터가 왼쪽으로,\n오른쪽 화살표를 클릭하면 오른쪽으로 움직입니다.",
                              ),
                            ],
                    ),
                    style: TextStyle(
                      color: const Color(0xFF5A3E2B),
                      fontSize: rW(15),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  rW: rW,
                  rH: rH,
                ),

              // 오브젝트 상호작용 임시 대사창 구역
              if (_interactionText != null)
                _buildDialogueBox(
                  textWidget: Text(
                    _interactionText!,
                    style: TextStyle(
                      color: const Color(0xFF5A3E2B),
                      fontSize: rW(15),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  rW: rW,
                  rH: rH,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 가상 패드 버튼 빌더
  Widget _buildDpadButton({
    required String imagePath,
    required VoidCallback onTapDown, // onPressed 대신 누를 때 이벤트 수렴
    required VoidCallback onTapUp, // 손을 뗄 때 이벤트 수렴
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(), // 버튼 밖으로 손가락이 미끄러져 나가도 멈추도록 예외 처리
      child: Container(
        width: rW(55),
        height: rH(55),
        color: Colors.transparent,
        child: Image.asset(imagePath, fit: BoxFit.contain),
      ),
    );
  }

  // 공통 커스텀 대사창 내비게이터 템플릿
  Widget _buildDialogueBox({
    required Widget textWidget,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    return Align(
      alignment: const Alignment(0, 0.2),
      child: IntrinsicWidth(
        // [AI 추가]: 자식 위젯(Text)의 실제 본연의 너비에 맞춰 Container 크기를 타이트하게 줄여주는 위젯
        child: Container(
          // [AI 수정]: 말풍선이 작아졌을 때 글자가 미어터지지 않도록 패딩 수치 최적화
          padding: EdgeInsets.symmetric(horizontal: rW(50), vertical: rH(23)),
          constraints: BoxConstraints(
            minWidth: rW(
              180,
            ), // [AI 수정]: 짧은 문장일 때 대사창이 이쁘게 작아질 수 있도록 최소 너비 제한을 대폭 낮춤
            maxWidth: rW(500),
          ),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/tutorial_dialogue_box.png'),
              fit: BoxFit.fill,
              // [AI 수정]: 원본 해상도(287x68) 테두리를 완벽히 보호하면서, 크기가 작아져도 도트 비율이 유지되도록 9패치 좌표 활성화
              // centerSlice: Rect.fromLTRB(30, 15, 257, 53),
            ),
          ),
          child: textWidget,
        ),
      ),
    );
  }
}
