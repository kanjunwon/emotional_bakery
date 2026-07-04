// lib/screens/tutorial_screen.dart

import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _tutorialStep = 0;

  // 월드 맵 전체 가로 길이 (전체 단일 이미지 가로 스케일 기준)
  final double _mapWidth = 1748.0;
  double _playerX = 150.0; // 캐릭터 시작 위치 (뒷골목 구역)
  String? _interactionText;

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    // 캐릭터가 화면 중심을 넘어설 때 배경을 반대 방향으로 밀어주는 카메라 오프셋 계산
    double screenWidth = w;
    double cameraX = (_playerX - screenWidth / 2).clamp(
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
                    // [AI 수정]: 기존 분할 배경 제거 후, 단일 와이드 통이미지(KakaoTalk_20260705_071927741.jpg) 배경으로 변경
                    Positioned(
                      left: 0,
                      top: 0,
                      width: rW(_mapWidth),
                      height: h,
                      child: Image.asset(
                        'assets/images/tutorial_bg_full.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // [AI 추가]: 1번 집 상호작용 구역 (노가다용 피그마 좌표 입력란)
                    Positioned(
                      left: rW(50),
                      top: rH(60),
                      width: rW(120),
                      height: rH(240),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText = "노인네 한 분이 살고 계시는 쓸쓸한 집이다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // [AI 추가]: 2번 집 상호작용 구역 (노가다용 피그마 좌표 입력란)
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
                                  "아이들의 웃음소리가 들리던 곳이었지만, 지금은 고요하다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // [AI 추가]: 3번 집 상호작용 구역 (노가다용 피그마 좌표 입력란)
                    Positioned(
                      left: rW(400),
                      top: rH(80),
                      width: rW(140),
                      height: rH(220),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText = "문고리에 먼지가 뽀얗게 쌓여있어.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // [AI 추가]: 4번 집 상호작용 구역 (노가다용 피그마 좌표 입력란)
                    Positioned(
                      left: rW(600),
                      top: rH(50),
                      width: rW(110),
                      height: rH(250),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText = "창문 너머로 무채색의 가구들이 덩그러니 놓여있다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 우측 목적지 (빛나는 빵집 건물) 터치 이벤트 구역 (메인 거리 끝자락)
                    Positioned(
                      left: rW(1400),
                      top: rH(40),
                      width: rW(220),
                      height: rH(260),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            if (_playerX >= rW(1300)) {
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                _interactionText =
                                    "빵집이 저기 멀리 보여. 화살표를 눌러 오른쪽으로 더 이동하자.";
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
                      child: Image.asset(
                        'assets/images/chaeon_idle.png',
                        width: rW(70),
                        height: rH(100),
                        fit: BoxFit.contain,
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
                    _buildDpadButton(
                      imagePath: 'assets/images/btn_left.png',
                      onPressed: () {
                        if (_tutorialStep == 2) {
                          setState(() {
                            if (_playerX > rW(30)) _playerX -= rW(25);
                          });
                        }
                      },
                      rW: rW,
                      rH: rH,
                    ),
                    SizedBox(width: rW(15)),
                    _buildDpadButton(
                      imagePath: 'assets/images/btn_right.png',
                      onPressed: () {
                        if (_tutorialStep == 2) {
                          setState(() {
                            if (_playerX < rW(_mapWidth - 100))
                              _playerX += rW(25);
                          });
                        }
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
    required VoidCallback onPressed,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: rW(45), vertical: rH(20)),
        constraints: BoxConstraints(minWidth: rW(400), maxWidth: rW(550)),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/tutorial_dialogue_box.png'),
            fit: BoxFit.fill,
            // 말풍선 이미지 크기가 텍스트 길이에 맞춰 늘어날 때 늘어날 중심 구역 픽셀 지정 (상하좌우 슬라이스 마진 설정)
            centerSlice: Rect.fromLTRB(40, 25, 260, 65),
          ),
        ),
        child: textWidget,
      ),
    );
  }
}
