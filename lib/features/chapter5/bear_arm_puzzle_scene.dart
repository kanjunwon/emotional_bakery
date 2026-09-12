// lib/features/chapter5/bear_arm_puzzle_scene.dart

// 챕터5 회상씬 미니게임: 곰인형 팔(bear_hand.png) 하나를 정답 위치로 드래그해서 붙이는
// 퍼즐. diary_puzzle_scene.dart(챕터3)의 GestureDetector로 위치를 직접 추적하는 방식을
// 그대로 따르지만, 조각이 1개뿐이라 SUCCESS 배너/여러 단계 전환 없이 훨씬 단순하게 짬

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:emotional_bakery/core/widgets/shared_ui.dart';

import 'bear_stitch_guide_scene.dart';

// 화면(뷰포트) 기준 874x507 좌표계. kitchen_screen.dart의 회상씬 미리보기(bear_bg+팔)도
// 이 값들을 그대로 가져다 써서 퍼즐로 넘어갈 때 팔 위치가 안 튀게 맞춤
const double kBearArmCanvasWidth = 874;
const double kBearArmCanvasHeight = 507;

// bear_hand.png 크기(정사각형)
const double kBearArmSize = 300;
// 팔 시작 위치(캔버스 기준). "오른쪽 끝"이라 x는 캔버스 우측에 딱 붙임. y는 화면 세로
// 중앙 근처로 임시 배치 - 화면 보면서 조정 예정
const double kBearArmStartX = kBearArmCanvasWidth - kBearArmSize;
const double kBearArmStartY = 100;
// 정답 위치(캔버스 기준)
const double kBearArmTargetX = 350;
const double kBearArmTargetY = 65;

// 스냅 허용 범위 비율. 팔 가로 길이 대비 몇 배까지 떨어져 있어도 스냅되는지.
// 디자이너랑 비율 보고 조정 예정
const double kBearArmSnapToleranceRatio = 0.35;

// 팔이 붙은 상태를 잠깐 보여준 뒤 onComplete() 호출 전까지
const Duration kBearArmAttachedHoldDuration = Duration(seconds: 1);

// 팔 붙은 상태 홀드가 끝나면 시작하는 줌인 연출: bear_bg의 특정 영역(아래 kBearZoomRect*)을
// 화면 가득 채우도록 확대함. 크롭 시작점/크기는 874x507 디자인 캔버스 기준값 -
// 디자이너랑 비율 보고 조정 예정
const double kBearZoomRectLeft = 292;
const double kBearZoomRectTop = 254;
const double kBearZoomRectWidth = 290;
const double kBearZoomRectHeight = 169;

// 줌인 애니메이션 재생 시간
const Duration kBearZoomInDuration = Duration(milliseconds: 800);
// 줌인이 다 끝나고(화면 가득 확대된 상태) 유지하는 시간. 끝나면 바느질 안내 문구가 뜸
const Duration kBearZoomHoldDuration = Duration(seconds: 2);

// 줌 크롭 영역(kBearZoomRect*)이 화면 안에 항상 전체가 들어오도록(레터박스) 만드는 단일
// 스케일과 중앙 정렬 오프셋. kitchen_screen.dart 등 다른 화면들이 쓰는 min(가로 배율, 세로
// 배율) 기반 레터박스 공식이랑 동일함 - 예전엔 가로/세로 배율을 각각 따로(w/kBearZoomRectWidth,
// h/kBearZoomRectHeight 독립적으로) 썼는데, 이러면 화면 비율이 크롭 비율(290:169)이랑
// 많이 다를 때(특히 모바일처럼 세로가 긴 화면) 세로만 몇 배씩 더 늘어나면서 bear_hand/
// bear_bg/바느질 점이 다 찌그러져 보이는 문제가 있었음(PC처럼 크롭 비율에 가까운 화면에서만
// 우연히 정상으로 보였던 것)
class BearZoomFit {
  const BearZoomFit({
    required this.scale,
    required this.anchorX,
    required this.anchorY,
  });

  final double scale;
  final double anchorX;
  final double anchorY;
}

BearZoomFit bearZoomFit(double w, double h) {
  final double scale = math.min(
    w / kBearZoomRectWidth,
    h / kBearZoomRectHeight,
  );
  return BearZoomFit(
    scale: scale,
    anchorX: (w - kBearZoomRectWidth * scale) / 2,
    anchorY: (h - kBearZoomRectHeight * scale) / 2,
  );
}

class BearArmPuzzleScene extends StatefulWidget {
  const BearArmPuzzleScene({super.key, required this.onComplete});

  // 팔 붙이기 -> 줌인 -> 바느질 안내 -> 바느질 미니게임(BearStitchGuideScene, SUCCESS
  // 연출까지 포함) 다 끝나면 호출됨. 다음 화면 전환은 호출부 책임
  final VoidCallback onComplete;

  @override
  State<BearArmPuzzleScene> createState() => _BearArmPuzzleSceneState();
}

class _BearArmPuzzleSceneState extends State<BearArmPuzzleScene>
    with SingleTickerProviderStateMixin {
  // 팔 현재 위치. 캔버스 874x507 좌표계 기준, 실제 화면
  Offset _armPosition = Offset.zero;
  bool _armPositionInitialized = false;
  // 팔이 정답 위치에 스냅됐는지. 스냅되면 더 이상 드래그 안 되고 홀드 후 onComplete 호출
  bool _isArmAttached = false;
  Timer? _attachedTimer;
  bool _imagesPrecached = false;

  // 줌인 진행도(0.0=원래 화면, 1.0=크롭 영역이 화면 가득 확대된 상태) 애니메이션
  late final AnimationController _zoomController;
  Timer? _zoomHoldTimer;

  // 줌 홀드가 끝나면 뜨는 바느질 안내 문구. 탭하면 닫히고 바느질 미니게임으로 전환됨
  bool _showStitchIntroGuide = false;
  // 바느질 미니게임(BearStitchGuideScene) 표시 여부
  bool _showStitchGame = false;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: kBearZoomInDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/bear_bg.png',
        'assets/images/bear_hand.png',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _attachedTimer?.cancel();
    _zoomHoldTimer?.cancel();
    _zoomController.dispose();
    super.dispose();
  }

  // 팔 드래그가 끝났을 때 호출됨. 스냅 허용 범위 안이면 정답 위치로 스냅하고 짧은 홀드 후
  // 줌인 연출 시작(_startZoomIn)
  void _handleArmDragEnd() {
    const Offset target = Offset(kBearArmTargetX, kBearArmTargetY);
    final double distance = (_armPosition - target).distance;
    if (distance > kBearArmSize * kBearArmSnapToleranceRatio) return;
    setState(() {
      _armPosition = target;
      _isArmAttached = true;
    });
    _attachedTimer = Timer(kBearArmAttachedHoldDuration, () {
      if (mounted) _startZoomIn();
    });
  }

  // 줌인 애니메이션을 재생하고, 다 끝나면 kBearZoomHoldDuration만큼 확대된 상태를
  // 유지한 뒤 바느질 안내 문구를 띄움
  void _startZoomIn() {
    _zoomController.forward().whenComplete(() {
      if (!mounted) return;
      _zoomHoldTimer = Timer(kBearZoomHoldDuration, () {
        if (mounted) setState(() => _showStitchIntroGuide = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        // 배경을 가로 기준으로만 꽉 채우므로(BoxFit.fitWidth 등가), 가로/세로 스케일이
        // 항상 같음. diary_puzzle_scene.dart처럼 cover 기반으로 scaleX/scaleY를 따로
        // 계산할 필요가 없어서 훨씬 단순함
        final double scale = w / kBearArmCanvasWidth;
        final double anchorY = (h - kBearArmCanvasHeight * scale) / 2;
        double wX(double refX) => refX * scale;
        double wY(double refY) => anchorY + refY * scale;
        double wSize(double refSize) => refSize * scale;

        // LayoutBuilder가 실제 w/h를 알려주는 첫 build()에서 시작 위치를 한 번만 채움
        if (!_armPositionInitialized) {
          _armPositionInitialized = true;
          _armPosition = const Offset(kBearArmStartX, kBearArmStartY);
        }

        // 줌 진행도 1(줌 다 끝난 상태)에서 쓸 목표 scale/anchor. bearZoomedPosition/Size랑
        // 완전히 같은 공식(bearZoomFit)이라 bear_stitch_guide_scene.dart로 넘어갈 때 화면이
        // 안 튀어 보임
        final BearZoomFit targetZoomFit = bearZoomFit(w, h);

        // 줌 홀드 -> 바느질 안내 -> 바느질 미니게임으로 넘어가는 대사창/캔버스에 쓰는 scale
        // 기준 함수. DialogueBoxFrame/CenteredDialogueBox는 rW 하나만 실제로 씀(가로 기준
        // 통일 관례라 wSize를 그대로 넘겨도 됨)
        double rW(double px) => wSize(px);

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _zoomController,
                builder: (context, child) {
                  // 줌 진행도 1(다 끝난 상태)에서 필요한 배율/오프셋을 먼저 고정값으로 구해둠.
                  // bg/hand는 이미 scale/anchorY로 한 번 배치돼 있어서(wX/wY/wSize) 그 위에
                  // 상대적으로 얼마나 더 확대(k1)/이동(targetOffsetX/Y)해야 최종 목표 좌표
                  // (targetZoomFit.anchorX+(x-CL)*targetZoomFit.scale, ...)랑 같은 결과가
                  // 나오는지 역산한 값 - x*scale*k1+targetOffsetX가 그 식이랑 같아지도록,
                  // y도 마찬가지로 풀면 이 식이 나옴
                  final double k1 = targetZoomFit.scale / scale;
                  final double targetOffsetX =
                      targetZoomFit.anchorX -
                      kBearZoomRectLeft * targetZoomFit.scale;
                  final double targetOffsetY =
                      targetZoomFit.anchorY -
                      kBearZoomRectTop * targetZoomFit.scale -
                      anchorY * k1;

                  // 줌 진행도(0~1)에 맞춰 스케일/오프셋을 "항등변환(0) -> 위에서 구한 목표값(1)"
                  // 사이로 선형보간함. 가로/세로를 각각 다른 배율로 따로 늘리지 않고 항상 같은
                  // 배율(relativeScale)로 확대하니까, 화면 비율이 크롭 비율이랑 달라도(모바일
                  // 세로 화면 등) 찌그러지지 않음
                  final double curvedT = Curves.easeInOut.transform(
                    _zoomController.value,
                  );
                  final double relativeScale = 1 + (k1 - 1) * curvedT;
                  final double offsetX = targetOffsetX * curvedT;
                  final double offsetY = targetOffsetY * curvedT;
                  return Transform.translate(
                    offset: Offset(offsetX, offsetY),
                    child: Transform.scale(
                      scale: relativeScale,
                      alignment: Alignment.topLeft,
                      child: child,
                    ),
                  );
                },
                child: Stack(
                  children: [
                    // 배경. 가로 기준으로 꽉 채움(위아래는 잘리거나 여백 생겨도 됨)
                    Positioned(
                      left: 0,
                      top: anchorY,
                      width: w,
                      height: wSize(kBearArmCanvasHeight),
                      child: Image.asset(
                        'assets/images/bear_bg.png',
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),

                    // 팔. 스냅되기 전까진 드래그 가능, 스냅되면 고정됨
                    Positioned(
                      left: wX(_armPosition.dx),
                      top: wY(_armPosition.dy),
                      width: wSize(kBearArmSize),
                      height: wSize(kBearArmSize),
                      child: GestureDetector(
                        onPanUpdate: _isArmAttached
                            ? null
                            : (details) {
                                setState(() {
                                  _armPosition += Offset(
                                    details.delta.dx / scale,
                                    details.delta.dy / scale,
                                  );
                                });
                              },
                        onPanEnd: _isArmAttached
                            ? null
                            : (_) => _handleArmDragEnd(),
                        child: Image.asset(
                          'assets/images/bear_hand.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 바느질 안내 문구. 줌 홀드가 끝나면 뜨고, 화면 아무 곳이나 탭하면 닫히고
              // 바느질 미니게임(BearStitchGuideScene)으로 전환됨. 곰인형 팔 안내창(딤+
              // CenteredDialogueBox, 화면 가로 중앙 정렬)이랑 동일한 스타일
              if (_showStitchIntroGuide)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _showStitchIntroGuide = false;
                        _showStitchGame = true;
                      });
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: CenteredDialogueBox(
                        textWidget: Text(
                          '바늘을 드래그해서\n곰인형의 팔을 바느질해주세요',
                          textAlign: TextAlign.center,
                          style: dialogueTextStyle(rW),
                        ),
                        rW: rW,
                        rH: rW,
                      ),
                    ),
                  ),
                ),

              // 바느질 미니게임. 배경(bear_bg+팔) 위에 점/선/바늘만 그리는 투명한 오버레이로
              // 얹음 - 예전엔 이 시점에 통째로 다른 위젯(배경 포함)으로 교체했는데, 그러면
              // 위젯 트리가 갈아끼워지면서 위의 AnimatedBuilder+배경 Stack이 dispose됐다가
              // 다시 마운트되는 그 찰나에 배경 없는 프레임이 한 번 그려져서 화면이 번쩍였음.
              // 지금처럼 같은 Stack 안에 그냥 추가하면 배경 쪽 위젯(Positioned 두 개, 그 안의
              // Image.asset들, AnimatedBuilder 전부)이 여기 오는 동안 한 번도 안 바뀌니까
              // Element/RenderObject가 계속 같은 걸 재사용해서 dispose/재생성 자체가 없음
              if (_showStitchGame)
                Positioned.fill(
                  child: BearStitchGuideScene(
                    // bear_stitch_guide_scene.dart의 SUCCESS 배너 -> bear_success.png ->
                    // 암전 마무리 연출까지 다 끝나면 호출됨
                    onComplete: () {
                      if (mounted) widget.onComplete();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
