// lib/features/prologue/tutorial_screen.dart

import 'package:flutter/material.dart';
import 'dart:async'; // 연속 이동 (화살표 꾹 누르기)
import '../chapter1/game_play_screen.dart';

class TutorialScreen extends StatefulWidget {
  // 튜토리얼 안내 문구(0, 1단계)를 건너뛰고 바로 마을 배경만 보여주고 싶을 때 2로 전달
  final int initialStep;
  // 채온이가 등장할 마을 좌표 (rW 변환 전 원본 디자인 좌표, 기본값은 뒷골목 시작 지점)
  final double initialPlayerX;
  // 등장 시 채온이가 왼쪽을 보도록 반전할지 여부 (빵집에서 나올 때 true)
  final bool initialFacingLeft;
  const TutorialScreen({
    super.key,
    this.initialStep = 0,
    this.initialPlayerX = 445,
    this.initialFacingLeft = false,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late int _tutorialStep = widget.initialStep;

  // 월드 맵 전체 가로 길이 (전체 단일 이미지 가로 스케일 기준)
  final double _mapWidth = 1352;
  double _playerX = 150; // 캐릭터 시작 위치 (뒷골목 구역)
  bool _isPlayerInitialized = false;
  String? _interactionText;

  // 연속 이동 타이머 및 캐릭터 상태 관리 변수
  Timer? _moveTimer;
  String _currentAction = 'idle';
  late bool _isLookingLeft = widget.initialFacingLeft; // 왼쪽인지 확인 여부

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    // UI 크롬(버튼, 대사창 등 화면에 고정되는 요소)에만 쓰는 스케일 함수
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;
    // 월드 요소는 세로 기준 하나로만 스케일 (챕터1 zoom 방식과 동일, rH랑 계산은 같은데 용도 구분용으로 분리)
    double zoom = h / 402;
    double zW(double worldPx) => worldPx * zoom;

    if (!_isPlayerInitialized) {
      _playerX = zW(widget.initialPlayerX);
      _isPlayerInitialized = true;
    }

    // 캐릭터가 화면 중심을 넘어설 때 배경을 반대 방향으로 밀어주는 카메라 오프셋 계산
    double screenWidth = w;
    double cameraX = (_playerX - zW(80)).clamp(
      0.0,
      zW(_mapWidth) - screenWidth,
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
              // 1층: 카메라 오프셋의 영향을 받는 인게임 월드 레이어 (배경, 오브젝트, 캐릭터)
              Positioned(
                left: -cameraX,
                top: 0,
                width: zW(_mapWidth),
                height: h,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      width: zW(_mapWidth),
                      height: rH(699),
                      child: Image.asset(
                        'assets/images/tutorial_bg_full.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 1번 집 상호작용 구역
                    Positioned(
                      left: zW(50),
                      top: rH(60),
                      width: zW(120),
                      height: rH(240),
                      child: GestureDetector(
                        onTapDown: (_) {
                          // 상태창이 떠 있으면 어떤 클릭이든 그 상태창을 닫기만 함
                          if (_interactionText != null) {
                            setState(() => _interactionText = null);
                          } else if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText = "클로에의 집이다.\n지금은 아무도 없는 거 같다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 2번 집 상호작용 구역
                    Positioned(
                      left: zW(200),
                      top: rH(60),
                      width: zW(120),
                      height: rH(240),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_interactionText != null) {
                            setState(() => _interactionText = null);
                          } else if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText =
                                  "피터의 집이다.\n예전에 한 번 들어가 본 적이 있다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 3번 집 상호작용 구역
                    Positioned(
                      left: zW(400),
                      top: rH(80),
                      width: zW(140),
                      height: rH(220),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_interactionText != null) {
                            setState(() => _interactionText = null);
                          } else if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText = "소피아의 집이다.\n소피아는 나에게 항상 친절하다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 4번 집 상호작용 구역
                    Positioned(
                      left: zW(600),
                      top: rH(50),
                      width: zW(110),
                      height: rH(250),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_interactionText != null) {
                            setState(() => _interactionText = null);
                          } else if (_tutorialStep == 2) {
                            setState(() {
                              _interactionText = "알렉스 씨의 집이다.\n들어가면 혼날 거 같다.";
                            });
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 우측 목적지 (빛나는 빵집 건물) 터치 이벤트 구역 (메인 거리 끝자락)
                    Positioned(
                      left: zW(850),
                      top: rH(40),
                      width: zW(220),
                      height: rH(260),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (_interactionText != null) {
                            setState(() => _interactionText = null);
                          } else if (_tutorialStep == 2) {
                            if (_playerX >= zW(950)) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GamePlayScreen(),
                                ),
                              );
                            } else {
                              setState(() {
                                _interactionText = "아직 빵집에 들어가기엔\n거리가 먼 거 같다.";
                              });
                            }
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // 주인공 캐릭터 (채온) 레이어
                    // Positioned로 즉시 갱신해야 카메라랑 같은 속도로 움직임 (AnimatedPositioned였을 땐 캐릭터가 밀리는 것처럼 보였음)
                    Positioned(
                      left: _playerX,
                      bottom: rH(50),
                      child: Transform.flip(
                        flipX: _isLookingLeft, // true일 때 이미지 반전
                        child: Image.asset(
                          // 오른쪽 에셋 2개만 가지고 walk와 idle을 스위칭함
                          _currentAction == 'walk'
                              ? 'assets/images/chaeon_walk_right.gif'
                              : 'assets/images/chaeon_idle_right.gif',
                          // 챕터1의 채온이(172 * zoom, zoom = h/402)와 동일한 크기 공식
                          width: zW(172),
                          height: rH(172),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2층: 가상 패드 및 유동 대사창 UI 레이어
              // 왼쪽 이동 버튼
              // 암전 단계(step 0/1)에서는 IgnorePointer로 터치 막음 -> 탭이 전체 화면 "다음으로" 핸들러로 넘어감
              Positioned(
                left: rW(686),
                bottom: rH(20),
                child: IgnorePointer(
                  ignoring: _tutorialStep < 2,
                  child: _buildDpadButton(
                    imagePath: 'assets/images/btn_left.png',
                    onTapDown: () {
                      if (_interactionText != null) {
                        setState(() => _interactionText = null);
                        return;
                      }
                      if (_tutorialStep == 2) {
                        _moveTimer?.cancel();
                        setState(() {
                          _currentAction = 'walk';
                          _isLookingLeft = true;
                        });
                        _moveTimer = Timer.periodic(
                          const Duration(milliseconds: 40),
                          (timer) {
                            if (_playerX > zW(30)) {
                              setState(() {
                                // 225 unit/sec (챕터1 채온이 속도와 동일) * 40ms
                                _playerX -= zW(9);
                              });
                            } else {
                              // 골목 왼쪽 끝에 도달하면 더 못 간다는 대사 노출
                              timer.cancel();
                              setState(() {
                                _currentAction = 'idle';
                                _interactionText = "빵집은 이쪽 방향이 아니다.\n오른쪽으로 가자.";
                              });
                            }
                          },
                        );
                      }
                    },
                    onTapUp: () {
                      _moveTimer?.cancel();
                      if (_tutorialStep == 2) {
                        setState(() {
                          _currentAction = 'idle';
                          _isLookingLeft = true;
                        });
                      }
                    },
                    rW: rW,
                    rH: rH,
                  ),
                ),
              ),

              // 오른쪽 이동 버튼
              Positioned(
                left: rW(778),
                bottom: rH(20),
                child: IgnorePointer(
                  ignoring: _tutorialStep < 2,
                  child: _buildDpadButton(
                    imagePath: 'assets/images/btn_right.png',
                    onTapDown: () {
                      if (_interactionText != null) {
                        setState(() => _interactionText = null);
                        return;
                      }
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
                              // 225 unit/sec (챕터1 채온이 속도와 동일) * 40ms
                              if (_playerX < zW(_mapWidth - 100)) {
                                _playerX += zW(9);
                              }
                            });
                          },
                        );
                      }
                    },
                    onTapUp: () {
                      _moveTimer?.cancel();
                      if (_tutorialStep == 2) {
                        setState(() {
                          _currentAction = 'idle';
                          _isLookingLeft = false;
                        });
                      }
                    },
                    rW: rW,
                    rH: rH,
                  ),
                ),
              ),

              // 가이드 대사(Step 0, 1)가 활성화되어 있을 때만 인게임 월드를 50% 어둡게 깔아주는 반투명 암전 레이어
              if (_tutorialStep < 2)
                Positioned.fill(
                  child: IgnorePointer(
                    // 암전 레이어가 터치 이벤트를 먹어버리지 않게 차단
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                ),

              // 메인 가이드 Box (Step 0, 1 시점 노출)
              if (_tutorialStep < 2)
                _buildDialogueBox(
                  textWidget: Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      children: _tutorialStep == 0
                          ? [
                              const TextSpan(
                                text: "화면을 클릭하면 다음 화면으로 넘어갑니다.\n물건이나 건물을 ",
                              ),
                              const TextSpan(
                                text: "클릭할 시, 정보를 얻을 수 있습니다.",
                                style: TextStyle(
                                  color: Color(0xFFD2691E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                      fontSize: rW(13),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SCDream',
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF5A3E2B),
                      fontSize: rW(13),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SCDream',
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
        width: rW(64),
        height: rH(64),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.contain,
          ),
        ),
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
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: rW(20), vertical: rH(15)),
          // minHeight 없으면 짧은 대사에서 박스가 테두리(60px)보다 작아져 모서리 찌그러짐
          constraints: BoxConstraints(
            minWidth: rW(180),
            maxWidth: rW(500),
            minHeight: rH(70),
          ),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/tutorial_dialogue_box.png'),
              fit: BoxFit.fill,
              // 실측해보니 테두리 4방향 다 30px 정도임 (기존 top=15는 잘못된 값이었음)
              centerSlice: Rect.fromLTRB(5, 5, 1114, 280),
            ),
          ),
          // 화살표를 Row에 넣으면 텍스트 중심이 화살표 폭만큼 밀려서 Stack으로 분리함
          child: Stack(
            children: [
              // 화살표랑 안 겹치게 여백만 최소로, 좌우는 대칭 줘야 가운데 정렬 안 깨짐
              Padding(
                padding: EdgeInsets.fromLTRB(rW(20), 0, rW(20), 0),
                child: textWidget,
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
}
