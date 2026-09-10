// lib/features/chapter5/bear_arm_puzzle_scene.dart

// 챕터5 회상씬 미니게임: 곰인형 팔(bear_hand.png) 하나를 정답 위치로 드래그해서 붙이는
// 퍼즐. diary_puzzle_scene.dart(챕터3)의 GestureDetector로 위치를 직접 추적하는 방식을
// 그대로 따르지만, 조각이 1개뿐이라 SUCCESS 배너/여러 단계 전환 없이 훨씬 단순하게 짬

import 'dart:async';
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

// 874x507 디자인 캔버스 좌표를 "줌인이 다 끝난(크롭 영역 kBearZoomRect*가 화면을 꽉 채운)
// 상태"의 화면 좌표로 변환. 아래 build()의 AnimatedBuilder 안 Transform이 진행도 1(줌 홀드
// 구간)에 도달했을 때랑 정확히 같은 결과가 나오는 계산식 - base scale(w/874)이랑 줌
// 배율(w/kBearZoomRectWidth 등)을 다 곱하고 나면 base scale이 상쇄돼서 이렇게 단순해짐.
// bear_stitch_guide_scene.dart가 이 함수를 그대로 가져다 써서 bear_hand 화면 좌표가 두
// 화면 사이에서 절대 어긋나지 않게 함(각자 따로 공식을 구현하면 나중에 조정하다가 어긋나기
// 쉬움)
Offset bearZoomedPosition(double designX, double designY, double w, double h) {
  return Offset(
    w * (designX - kBearZoomRectLeft) / kBearZoomRectWidth,
    h * (designY - kBearZoomRectTop) / kBearZoomRectHeight,
  );
}

// bearZoomedPosition이랑 동일한 좌표계에서 크기(너비/높이)를 변환
Size bearZoomedSize(double designWidth, double designHeight, double w, double h) {
  return Size(
    designWidth * w / kBearZoomRectWidth,
    designHeight * h / kBearZoomRectHeight,
  );
}

class BearArmPuzzleScene extends StatefulWidget {
  const BearArmPuzzleScene({super.key, required this.onComplete});

  // 팔 붙이기 -> 줌인 -> 바느질 안내 -> 바느질 미니게임(BearStitchGuideScene)까지 다 끝나면
  // 호출됨. 다음 화면 전환은 호출부 책임. 지금은 바느질 미니게임 쪽이 TODO라 실제로는 아직
  // 호출 안 됨(bear_stitch_guide_scene.dart의 _handlePanEnd 주석 참고)
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

        // 줌 시작 사각형(화면 전체, 줌 진행도 0일 때)과 목표 사각형(kBearZoomRect*를 화면
        // 좌표로 옮긴 것, 줌 진행도 1일 때)을 화면 좌표계로 미리 구해둠. wX/wY/wSize가 위에서
        // 팔 위치 계산에 쓰던 것과 동일한 스케일/anchorY 기준이라 여기서도 그대로 재사용
        final Rect zoomStartRect = Rect.fromLTWH(0, 0, w, h);
        final Rect zoomTargetRect = Rect.fromLTWH(
          wX(kBearZoomRectLeft),
          wY(kBearZoomRectTop),
          wSize(kBearZoomRectWidth),
          wSize(kBearZoomRectHeight),
        );

        // 줌 홀드 -> 바느질 안내 -> 바느질 미니게임으로 넘어가는 대사창/캔버스에 쓰는 scale
        // 기준 함수. DialogueBoxFrame/CenteredDialogueBox는 rW 하나만 실제로 씀(가로 기준
        // 통일 관례라 wSize를 그대로 넘겨도 됨)
        double rW(double px) => wSize(px);

        // 바느질 미니게임으로 넘어가면 BearStitchGuideScene이 배경(bear_bg+팔)까지 자체적으로
        // 다시 그리므로, 여기 있는 줌 Stack은 그 밑에 깔아둘 필요 없이 통째로 교체함
        if (_showStitchGame) {
          return Container(
            color: Colors.black,
            child: BearStitchGuideScene(
              onComplete: () {
                // TODO: 9개 구간 다 완료되면 다음 단계 연결 예정. 지금은 bear_stitch_guide_scene.dart
                // 쪽에서 이 콜백을 아직 안 불러서 여기까지 도달 안 함
                if (mounted) widget.onComplete();
              },
            ),
          );
        }

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _zoomController,
                builder: (context, child) {
                  // 줌 진행도에 맞춰 시작 사각형 -> 목표 사각형으로 보간한 "현재 보이는
                  // 영역"을 구하고, 그 영역이 화면 전체를 채우도록 확대/이동하는 행렬을 만듦.
                  // 진행도 0일 때 currentRect가 화면 전체 그대로라 변환 결과가 항등변환이 됨
                  final Rect currentRect = Rect.lerp(
                    zoomStartRect,
                    zoomTargetRect,
                    Curves.easeInOut.transform(_zoomController.value),
                  )!;
                  final double zoomScaleX = w / currentRect.width;
                  final double zoomScaleY = h / currentRect.height;
                  // topLeft 기준으로 먼저 확대한 뒤, currentRect의 좌상단이 화면 원점(0,0)에
                  // 오도록 밀어줌 - 두 변환을 합치면 currentRect가 화면 전체를 꽉 채우게 됨
                  return Transform.translate(
                    offset: Offset(
                      -currentRect.left * zoomScaleX,
                      -currentRect.top * zoomScaleY,
                    ),
                    child: Transform.scale(
                      scaleX: zoomScaleX,
                      scaleY: zoomScaleY,
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
            ],
          ),
        );
      },
    );
  }
}
