// lib/features/chapter5/bear_stitch_guide_scene.dart

// 챕터5 회상씬 미니게임 2단계: 곰인형 팔 붙이기(bear_arm_puzzle_scene.dart) 줌인+안내창
// 다음에 이어지는 바느질 미니게임. 점 9개를 순서대로 드래그해서 이어붙이는 방식.
// 배경(bear_bg+bear_hand)은 bear_arm_puzzle_scene.dart가 줌인을 다 끝낸 시점의 화면을
// 그대로 재현함 - kBearZoomRect*(크롭 영역)를 그대로 가져다 써서 동일한 좌표계로 계산하므로
// 두 화면 사이에 배경이 튀어 보이지 않음

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bear_arm_puzzle_scene.dart';

// 바느질 점 9개 좌표. bear_arm_puzzle_scene.dart의 줌 크롭 영역(kBearZoomRectWidth x
// kBearZoomRectHeight = 290x169)을 그대로 좌표계로 씀 - 크롭 영역 좌상단이 (0,0)
const List<Offset> kBearStitchPoints = [
  Offset(125, 54),
  Offset(112, 78),
  Offset(136, 71),
  Offset(130, 100),
  Offset(150, 82),
  Offset(150, 110),
  Offset(168, 89),
  Offset(174, 115),
  Offset(186, 93),
];

// 점 9개 사이 구간 개수(점 개수 - 1)
final int kBearStitchSegmentCount = kBearStitchPoints.length - 1;

// 점(원) 지름/색
const double kBearStitchDotDiameter = 8;
const Color kBearStitchDotColor = Color(0xFFFF9743);

// 가이드 선(미완료 구간) 굵기/색
const double kBearStitchGuideLineWidth = 4;
const Color kBearStitchGuideLineColor = Color(0xFFFFB57B);

// 완료된 구간 선 굵기/색
const double kBearStitchCompletedLineWidth = 2;
const Color kBearStitchCompletedLineColor = Color(0xFFFF7100);

// 드래그 시작/끝 판정 허용 범위(반지름, 290x169 좌표계 기준). 점 지름(8)보다 넉넉하게 잡아서
// 손가락으로도 잘 잡히게 함 - 디자이너랑 비율 보고 조정 예정
const double kBearStitchHitToleranceRadius = 12;

// 드래그 경로가 활성 구간의 가이드선(시작점-끝점을 잇는 직선)에서 수직으로 벗어나도 되는
// 허용 범위. 이걸 넘어서면 그 구간 드래그가 취소되고 다시 시작점부터 그어야 함 - 너무
// 빡빡하면 손 떨림에도 취소되고 너무 헐렁하면 아무렇게나 그어도 통과되니 점 사이 거리/선
// 굵기 보고 중간 정도로 잡음. 화면 보면서 조정 예정
const double kBearStitchPathToleranceRadius = 25;

// 바늘 이미지 크기(정사각형)
const double kBearStitchNeedleSize = 120;

// bear_bg.png 원본 파일 해상도(가로x세로, PNG 헤더 확인함: 3496x2032). cacheWidth/
// cacheHeight를 이보다 더 크게 요청하면 디코더가 원본보다 업스케일해서 디코딩하는데, 이때
// 화질이 흐려짐(줌으로 화면에 크게 띄우면서 cacheWidth/cacheHeight가 원본 해상도를 넘어서던
// 게 bear_bg만 흐릿해 보이던 진짜 원인 - 아래 cachePx 호출부에서 이 값 이상으로 못 넘어가게
// clamp함)
const int kBearBgNativeWidth = 3496;
const int kBearBgNativeHeight = 2032;

class BearStitchGuideScene extends StatefulWidget {
  const BearStitchGuideScene({super.key, required this.onComplete});

  // 9개 구간을 다 이어붙이면 호출됨. 지금은 호출 지점을 비워둠(_handlePanEnd의 TODO 참고)
  final VoidCallback onComplete;

  @override
  State<BearStitchGuideScene> createState() => _BearStitchGuideSceneState();
}

class _BearStitchGuideSceneState extends State<BearStitchGuideScene> {
  // 지금까지 완료된 구간 인덱스 집합(0 = 점1-점2 구간, ... 7 = 점8-점9 구간)
  final Set<int> _completedSegments = {};
  // 다음에 이어붙여야 하는 구간 인덱스. 이 구간의 시작점 근처에서만 드래그가 시작됨
  int _activeSegmentIndex = 0;
  bool _isDragging = false;
  // 드래그 중인 바늘 위치(290x169 좌표계 기준). 드래그 중이 아니면 null
  Offset? _needleLocalPosition;
  bool _imagesPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/bear_bg.png',
        'assets/images/bear_hand.png',
        'assets/images/needle.png',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  // 드래그 시작. 활성 구간의 시작점 근처가 아니면 무시(비활성 구간이거나 엉뚱한 위치)
  void _handlePanStart(DragStartDetails details, double scaleX, double scaleY) {
    if (_activeSegmentIndex >= kBearStitchSegmentCount) return;
    final Offset local = Offset(
      details.localPosition.dx / scaleX,
      details.localPosition.dy / scaleY,
    );
    final Offset segmentStart = kBearStitchPoints[_activeSegmentIndex];
    if ((local - segmentStart).distance > kBearStitchHitToleranceRadius) {
      return;
    }
    setState(() {
      _isDragging = true;
      _needleLocalPosition = local;
    });
  }

  // 드래그 중. 활성 구간의 끝점 근처에 닿으면 그 구간을 완료 처리하고 다음 구간으로 넘어감.
  // while로 계속 체크하는 이유: 끊지 않고 한 번에 쭉 이어서 그리는 경우에도 지나친 점들이
  // 순서대로 계속 완료 처리되게 하기 위함(구간별로 끊어서 그려도 당연히 동작함)
  void _handlePanUpdate(
    DragUpdateDetails details,
    double scaleX,
    double scaleY,
  ) {
    if (!_isDragging) return;
    final Offset local = Offset(
      details.localPosition.dx / scaleX,
      details.localPosition.dy / scaleY,
    );

    // 활성 구간의 가이드선(시작점-끝점을 잇는 직선)에서 포인터가 수직으로 너무 벗어났으면
    // 드래그를 취소함. 이게 없으면 시작점 근처에서 출발해서 경로랑 무관하게(예: 그냥 직선으로)
    // 끝점 근처까지만 가도 성공 판정이 되는 문제가 있었음 - 경로를 실제로 따라가는지 매
    // 업데이트마다 확인해야 함
    final Offset pathSegmentStart = kBearStitchPoints[_activeSegmentIndex];
    final Offset pathSegmentEnd = kBearStitchPoints[_activeSegmentIndex + 1];
    final double pathDeviation = _distanceToSegment(
      local,
      pathSegmentStart,
      pathSegmentEnd,
    );
    if (pathDeviation > kBearStitchPathToleranceRadius) {
      setState(() {
        _isDragging = false;
        _needleLocalPosition = null;
      });
      return;
    }

    setState(() {
      _needleLocalPosition = local;
      while (_activeSegmentIndex < kBearStitchSegmentCount) {
        final Offset segmentEnd = kBearStitchPoints[_activeSegmentIndex + 1];
        if ((local - segmentEnd).distance <= kBearStitchHitToleranceRadius) {
          _completedSegments.add(_activeSegmentIndex);
          _activeSegmentIndex++;
        } else {
          break;
        }
      }
    });
  }

  // 점 P에서 선분 A-B까지의 수직 거리. AP 벡터를 AB 벡터에 투영해서 선분 위에서 가장 가까운
  // 점을 구하고(0~1로 clamp해서 선분 밖으로는 안 나가게 함), 그 점이랑 P 사이 거리를 구하는
  // 표준적인 점-선분 거리 계산 방식
  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLengthSquared == 0) return (p - a).distance;
    final Offset ap = p - a;
    final double t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLengthSquared).clamp(
      0.0,
      1.0,
    );
    final Offset closestPoint = a + ab * t;
    return (p - closestPoint).distance;
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _needleLocalPosition = null;
    });
    if (_activeSegmentIndex >= kBearStitchSegmentCount) {
      // TODO: 9개 구간 다 완료되면 다음 단계 연결 예정. 지금은 전부 완료된 상태(선이 전부
      // 진한 주황으로 바뀐 상태)로 그냥 멈춰있음 - widget.onComplete()는 여기서 호출 예정
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        // bear_arm_puzzle_scene.dart가 줌인을 다 끝낸 화면과 동일한 좌표계: 크롭 영역
        // (kBearZoomRect*)의 좌상단이 화면 (0,0), 크롭 영역 전체가 화면을 꽉 채움
        final double scaleX = w / kBearZoomRectWidth;
        final double scaleY = h / kBearZoomRectHeight;
        double wX(double localX) => localX * scaleX;
        double wY(double localY) => localY * scaleY;

        // 고해상도 원본을 화면에 필요한 만큼만 디코딩하도록 cacheWidth/cacheHeight를 계산.
        // 실제 렌더링될 논리 픽셀 크기 * devicePixelRatio(기기 실제 배율) 정도면 화질 손실
        // 없이 딱 필요한 만큼만 디코딩됨 - 원본 해상도가 아무리 높아도 메모리/디코딩 비용이
        // 이 크기로 고정됨
        final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        int cachePx(double logicalSize) =>
            (logicalSize * devicePixelRatio).round();

        // 배경/팔 화면 좌표+크기. bear_arm_puzzle_scene.dart의 bearZoomedPosition/
        // bearZoomedSize를 그대로 가져다 써서, 그 화면이 줌인을 다 끝낸 상태랑 좌표 계산
        // 공식 자체가 완전히 동일함(따로 구현하지 않음) - 두 화면에서 bear_hand 위치가
        // 어긋날 수가 없음
        final Offset bgPos = bearZoomedPosition(0, 0, w, h);
        final Size bgSize = bearZoomedSize(
          kBearArmCanvasWidth,
          kBearArmCanvasHeight,
          w,
          h,
        );
        final Offset handPos = bearZoomedPosition(
          kBearArmTargetX,
          kBearArmTargetY,
          w,
          h,
        );
        final Size handSize = bearZoomedSize(kBearArmSize, kBearArmSize, w, h);

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 배경. bear_arm_puzzle_scene.dart의 줌인된 화면(bear_bg+bear_hand)을 그대로
              // 재현함 - bearZoomedPosition/bearZoomedSize가 그 화면의 Rect.lerp 줌인
              // 애니메이션 끝(진행도 1)에 도달했을 때와 수학적으로 동일한 결과를 내서 배경이
              // 안 튀어 보임
              Positioned(
                left: bgPos.dx,
                top: bgPos.dy,
                width: bgSize.width,
                height: bgSize.height,
                child: Image.asset(
                  'assets/images/bear_bg.png',
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // 원본(kBearBgNativeWidth/Height)보다 크게 요청하지 않게 clamp - 줌 때문에
                  // bgSize가 원본 해상도를 넘어서는 경우가 있어서(특히 화면이 크거나 dpr이
                  // 높은 기기) 이게 없으면 디코더가 업스케일하면서 흐려짐
                  cacheWidth: math.min(
                    cachePx(bgSize.width),
                    kBearBgNativeWidth,
                  ),
                  cacheHeight: math.min(
                    cachePx(bgSize.height),
                    kBearBgNativeHeight,
                  ),
                ),
              ),
              // 팔은 이미 붙은 상태(kBearArmTargetX/Y 위치)로 고정 표시
              Positioned(
                left: handPos.dx,
                top: handPos.dy,
                width: handSize.width,
                height: handSize.height,
                child: Image.asset(
                  'assets/images/bear_hand.png',
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  cacheWidth: cachePx(handSize.width),
                  cacheHeight: cachePx(handSize.height),
                ),
              ),

              // 점/선을 그리는 판. 드래그 판정도 이 위에서 같이 처리
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) =>
                      _handlePanStart(details, scaleX, scaleY),
                  onPanUpdate: (details) =>
                      _handlePanUpdate(details, scaleX, scaleY),
                  onPanEnd: _handlePanEnd,
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _BearStitchPainter(
                      scaleX: scaleX,
                      scaleY: scaleY,
                      completedSegments: _completedSegments,
                    ),
                  ),
                ),
              ),

              // 바늘. 드래그 중일 때만 손가락/마우스 위치를 따라다님. IgnorePointer로 감싸서
              // 자기 자신이 GestureDetector의 드래그 판정을 가로막지 않게 함
              if (_isDragging && _needleLocalPosition != null)
                Positioned(
                  left:
                      wX(_needleLocalPosition!.dx) - kBearStitchNeedleSize / 2,
                  top: wY(_needleLocalPosition!.dy) - kBearStitchNeedleSize / 2,
                  width: kBearStitchNeedleSize,
                  height: kBearStitchNeedleSize,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/needle.png',
                      fit: BoxFit.contain,
                      cacheWidth: cachePx(kBearStitchNeedleSize),
                      cacheHeight: cachePx(kBearStitchNeedleSize),
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

// 점 9개 + 이어주는 선을 그리는 페인터. 선 -> 점 순서로 그려서 점이 선 위에 보이게 함
class _BearStitchPainter extends CustomPainter {
  _BearStitchPainter({
    required this.scaleX,
    required this.scaleY,
    required this.completedSegments,
  });

  final double scaleX;
  final double scaleY;
  final Set<int> completedSegments;

  Offset _toScreen(Offset local) =>
      Offset(local.dx * scaleX, local.dy * scaleY);

  @override
  void paint(Canvas canvas, Size size) {
    // 점/선 굵기처럼 "방향 없는" 크기는 scaleX/scaleY를 각각 따로 적용하면 안 됨(점이
    // 타원으로 찌그러져 보이는 원인). 화면이 가로/세로로 서로 다른 배율로 늘어나 있어도
    // 항상 정원/일정한 굵기로 보이게, 둘 중 더 작은 값 하나로 통일해서 씀
    final double uniformScale = math.min(scaleX, scaleY);
    final Paint guideLinePaint = Paint()
      ..color = kBearStitchGuideLineColor
      ..strokeWidth = kBearStitchGuideLineWidth * uniformScale
      ..strokeCap = StrokeCap.round;
    final Paint completedLinePaint = Paint()
      ..color = kBearStitchCompletedLineColor
      ..strokeWidth = kBearStitchCompletedLineWidth * uniformScale
      ..strokeCap = StrokeCap.round;

    // 가이드 선을 먼저 그리고 점을 나중에 그려야 점이 선 위에 보임
    for (int i = 0; i < kBearStitchPoints.length - 1; i++) {
      final Offset start = _toScreen(kBearStitchPoints[i]);
      final Offset end = _toScreen(kBearStitchPoints[i + 1]);
      canvas.drawLine(
        start,
        end,
        completedSegments.contains(i) ? completedLinePaint : guideLinePaint,
      );
    }

    final Paint dotPaint = Paint()..color = kBearStitchDotColor;
    for (final point in kBearStitchPoints) {
      final Offset center = _toScreen(point);
      // 정원으로 그려야 하니 drawCircle로 바꿈(drawOval에 가로/세로 다른 크기를 넣으면
      // 그 자체로 타원이 되는 구조라 애초에 이 방식이 문제였음)
      canvas.drawCircle(
        center,
        kBearStitchDotDiameter * uniformScale / 2,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BearStitchPainter oldDelegate) {
    return oldDelegate.scaleX != scaleX ||
        oldDelegate.scaleY != scaleY ||
        oldDelegate.completedSegments.length != completedSegments.length;
  }
}
