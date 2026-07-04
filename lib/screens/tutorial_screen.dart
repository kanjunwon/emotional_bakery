// lib/screens/tutorial_screen.dart

import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _tutorialStep = 0;

  final double _mapWidth = 1748.0;
  double _playerX = 150.0; // 캐릭터 시작 위치 (뒷골목 구역)
  String? _interactionText;

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

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
                left: -cameraX, // [AI 추가]: 계산된 카메라 값만큼 월드 전체를 왼쪽으로 밀어냄
                top: 0,
                width: rW(_mapWidth),
                height: h,
                child: Stack(
                  children: [
                    // 1-1번 배경 - 왼쪽 뒷골목 이미지 에셋
                    Positioned(
                      left: 0,
                      top: 0,
                      width: rW(874),
                      height: h,
                      child: Image.asset(
                        'assets/images/tutorial_bg_alley.png',
                        fit: BoxFit.cover,
                      ),
                    ),

                    // 1-2번 배경 - 우측 메인 빵집 거리 이미지 에셋
                    Positioned(
                      left: rW(874),
                      top: 0,
                      width: rW(874),
                      height: h,
                      child: Image.asset(
                        'assets/images/tutorial_bg_main.png',
                        fit: BoxFit.cover,
                      ),
                    ),

                    // 2층: 왼쪽 일반 건물들 터치 이벤트 구역 (뒷골목 영역 제한)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: rW(800),
                      height: rH(300),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText =
                                  "문이 굳게 닫혀있어. 지금은 들어갈 수 없을 것 같다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 3층: 우측 목적지 터치 이벤트 구역 (메인 거리 끝자락)
                    Positioned(
                      left: rW(1400),
                      top: rH(40),
                      width: rW(220),
                      height: rH(260),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_tutorialStep == 2) {
                            // 월드 확장에 따라 최종 목적지 도달 기준 좌표를 rW(1300) 이상으로 보정
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

                    // 4층: 주인공 캐릭터 (채온) 레이어
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
              // 2층: 카메라의 영향을 받지 않는 고정 고정 UI 레이어 (방향키, 대사창)
              // --------------------------------------------------------

              // 5층: 하단 가상 패드 (방향키 컨트롤러) 구역
              Positioned(
                right: rW(20),
                bottom: rH(20),
                child: Row(
                  children: [
                    // 왼쪽 이동 버튼
                    _buildDpadButton(
                      imagePath:
                          'assets/images/tutorial_btn_left.png', // 아이콘을 왼쪽 방향키 이미지로 교체
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
                    // 오른쪽 이동 버튼
                    _buildDpadButton(
                      imagePath:
                          'assets/images/tutorial_btn_right.png', // 아이콘을 오른쪽 방향키 이미지로 교체
                      onPressed: () {
                        if (_tutorialStep == 2) {
                          setState(() {
                            // 이동 가능한 최대 한계 좌표를 확장된 맵 끝자리로 보정
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

              // 6층: 메인 가이드 대사창 (Step 0, 1 시점 노출)
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
                              const TextSpan(text: ", 정보를 얻을 수 있습니다. ▼"),
                            ]
                          : [
                              const TextSpan(
                                text:
                                    "왼쪽 화살표를 클릭하면 캐릭터가 왼쪽으로,\n오른쪽 화살표를 클릭하면 오른쪽으로 움직입니다. ▼",
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

              // 7층: 오브젝트 상호작용 임시 대사창 구역
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 컨테이너 레이아웃 대사창 이미지 에셋으로 변경하여 백그라운드 매핑
          Image.asset(
            'assets/images/tutorial_dialogue_box.png',
            width: rW(520),
            height: rH(110),
            fit: BoxFit.fill,
          ),
          Container(
            width: rW(460),
            padding: EdgeInsets.symmetric(horizontal: rW(10)),
            child: textWidget,
          ),
        ],
      ),
    );
  }
}
