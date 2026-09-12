// lib/features/chapter5/bear_stitch_guide_scene.dart

// 챕터5 회상씬 미니게임 2단계: 곰인형 팔 붙이기(bear_arm_puzzle_scene.dart) 줌인+안내창
// 다음에 이어지는 바느질 미니게임. 점 9개를 순서대로 드래그해서 이어붙이는 방식.
// 배경(bear_bg+bear_hand)은 더 이상 이 위젯이 직접 그리지 않음 - bear_arm_puzzle_scene.dart가
// 줌인을 다 끝낸 뒤 이미 화면에 그리고 있는 배경 위에, 이 위젯이 점/선/바늘만 그리는 투명한
// 오버레이로 얹히는 구조. 예전엔 이 위젯이 배경까지 통째로 다시 그렸는데, 그러면 전환되는
// 순간 위젯 트리가 갈아끼워지면서 배경이 dispose됐다가 다시 마운트되는 프레임이 생겨서
// 화면이 번쩍이는 문제가 있었음 - bearZoomFit()/kBearZoomRect*는 그대로 가져다 써서 배경
// 이랑 좌표계는 여전히 완전히 동일함

import 'dart:async';
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

// 바늘 이미지 크기(정사각형). 화면 보면서 추가 조정 예정
const double kBearStitchNeedleSize = 45;

// needle.png 원본 파일(2368x2368 정사각형)을 직접 열어서 불투명 픽셀 범위를 스캔해보니,
// 바늘 그림 자체는 캔버스 위쪽 절반에만 그려져 있고 아래쪽 절반은 완전히 투명한 여백이었음
// (opaque bbox: y=24~1184, 정확히 캔버스 높이의 절반). fit:BoxFit.contain으로 정사각형
// 박스에 그대로 넣으면 박스를 키워도 절반은 항상 빈 공간이라 커지는 게 잘 안 느껴졌던
// 진짜 원인 - 아래 needle Positioned에서 이 비율만큼만 크롭해서 보여줌(OverflowBox+ClipRect).
// 에셋을 여백 없이 다시 뽑으면 이 값을 1.0으로 바꾸면 됨
const double kBearStitchNeedleContentHeightRatio = 0.5;

// 9개 구간 다 완료된 뒤 SUCCESS 배너 -> bear_success.png -> 암전 순으로 이어지는 마무리
// 연출 관련 상수. SUCCESS 배너 노출 시간은 다른 미니게임들(diary_puzzle_scene.dart의
// _successHoldDuration=1800ms 등) 참고해서 800ms로 시작
const Duration kBearStitchSuccessBannerHoldDuration = Duration(
  milliseconds: 800,
);
// bear_success.png 노출 시간. chapter3_diary_success_after.png 노출 시간
// (kitchen_screen.dart의 _chapter3DiarySuccessAfterHoldDuration, 1800ms)이랑 똑같이 맞춤
const Duration kBearStitchSuccessAfterHoldDuration = Duration(
  milliseconds: 1800,
);
// bear_success.png 다음 암전 유지 시간. bear_arm_puzzle_scene.dart의
// kBearZoomHoldDuration(2초)이랑 동일한 패턴
const Duration kBearStitchBlackoutHoldDuration = Duration(seconds: 2);

// SUCCESS 배너 위치/크기. 챕터1/2/3 미니게임 성공 연출(diary_puzzle_scene.dart 등)이랑
// 동일한 값을 874x507 캔버스(kBearArmCanvasWidth/Height) 기준으로 그대로 가져다 씀
const double kBearStitchSuccessBannerLeft = 158;
const double kBearStitchSuccessBannerTop = 43;
const double kBearStitchSuccessBannerWidth = 557;
const double kBearStitchSuccessBannerHeight = 129;

class BearStitchGuideScene extends StatefulWidget {
  const BearStitchGuideScene({super.key, required this.onComplete});

  // 9개 구간을 다 이어붙이고 마무리 연출(_startCompletionSequence)까지 끝나면 호출됨
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
  bool _imagesPrecached = false;

  // 포인터가 눌려있는 동안의 위치(290x169 좌표계 기준). 성공 판정(_isDragging, 구간 완료
  // 등)이랑 무관하게, 포인터가 눌려있으면 항상 갱신됨 - 바늘을 항상 표시하는 용도로만 씀
  // (렌더링에서만 참조)
  Offset? _pointerLocalPosition;

  // 9개 구간 다 완료된 뒤 마무리 연출(SUCCESS 배너 -> bear_success.png -> 암전)이 이미
  // 시작됐는지. 여러 번 호출돼도 한 번만 실행되게 막는 용도
  bool _completionSequenceStarted = false;
  bool _showSuccessBanner = false;
  bool _showBearSuccessImage = false;
  bool _showBlackout = false;
  Timer? _successBannerTimer;
  Timer? _bearSuccessImageTimer;
  Timer? _blackoutTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      // 배경(bear_bg/bear_hand)은 bear_arm_puzzle_scene.dart가 이미 그려서 갖고 있으니
      // 여기서는 이 오버레이가 새로 쓰는 이미지들만 미리 로드하면 됨
      const List<String> assetsToPrecache = [
        'assets/images/needle.png',
        'assets/images/minigame_success.png',
        'assets/images/bear_success.png',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _successBannerTimer?.cancel();
    _bearSuccessImageTimer?.cancel();
    _blackoutTimer?.cancel();
    super.dispose();
  }

  // 9개 구간 다 완료되면 SUCCESS 배너 -> bear_success.png -> 암전 순서로 이어지는 마무리
  // 연출을 시작하고, 끝에서 widget.onComplete()를 호출함
  void _startCompletionSequence() {
    if (_completionSequenceStarted) return;
    _completionSequenceStarted = true;
    setState(() => _showSuccessBanner = true);
    _successBannerTimer = Timer(kBearStitchSuccessBannerHoldDuration, () {
      if (!mounted) return;
      setState(() {
        _showSuccessBanner = false;
        _showBearSuccessImage = true;
      });
      _bearSuccessImageTimer = Timer(kBearStitchSuccessAfterHoldDuration, () {
        if (!mounted) return;
        setState(() {
          _showBearSuccessImage = false;
          _showBlackout = true;
        });
        _blackoutTimer = Timer(kBearStitchBlackoutHoldDuration, () {
          if (mounted) widget.onComplete();
        });
      });
    });
  }

  // 드래그 시작. 활성 구간의 시작점 근처가 아니면 무시(비활성 구간이거나 엉뚱한 위치)
  void _handlePanStart(
    DragStartDetails details,
    double scaleX,
    double scaleY,
    double anchorX,
    double anchorY,
  ) {
    // 레터박스 오프셋(anchorX/Y)만큼 빼고 스케일로 나눠야 로컬(290x169) 좌표가 됨 -
    // 레터박스가 생기면 화면 원점(0,0)이 더 이상 크롭 영역의 좌상단이 아니라서 필요함
    final Offset local = Offset(
      (details.localPosition.dx - anchorX) / scaleX,
      (details.localPosition.dy - anchorY) / scaleY,
    );
    // 바늘은 판정 결과랑 상관없이 포인터가 눌린 위치에 항상 보여야 해서, 아래 유효 구간
    // 판정이랑 별개로 여기서 먼저 갱신함
    setState(() => _pointerLocalPosition = local);

    if (_activeSegmentIndex >= kBearStitchSegmentCount) return;
    final Offset segmentStart = kBearStitchPoints[_activeSegmentIndex];
    if ((local - segmentStart).distance > kBearStitchHitToleranceRadius) {
      return;
    }
    setState(() {
      _isDragging = true;
    });
  }

  // 드래그 중. 활성 구간의 끝점 근처에 닿으면 그 구간을 완료 처리하고 다음 구간으로 넘어감.
  // while로 계속 체크하는 이유: 끊지 않고 한 번에 쭉 이어서 그리는 경우에도 지나친 점들이
  // 순서대로 계속 완료 처리되게 하기 위함(구간별로 끊어서 그려도 당연히 동작함)
  void _handlePanUpdate(
    DragUpdateDetails details,
    double scaleX,
    double scaleY,
    double anchorX,
    double anchorY,
  ) {
    // 레터박스 오프셋(anchorX/Y)만큼 빼고 스케일로 나눠야 로컬(290x169) 좌표가 됨
    final Offset local = Offset(
      (details.localPosition.dx - anchorX) / scaleX,
      (details.localPosition.dy - anchorY) / scaleY,
    );
    // 바늘은 판정 결과랑 상관없이 포인터 위치를 항상 따라가야 해서 여기서 먼저 갱신함
    setState(() => _pointerLocalPosition = local);

    if (!_isDragging) return;

    // 9개 구간을 다 완료한 뒤에도(_activeSegmentIndex가 kBearStitchSegmentCount에 도달한
    // 뒤에도) 손을 안 떼고 계속 드래그 중이면, 더 이상 활성 구간이 없어서 바로 아래
    // kBearStitchPoints[_activeSegmentIndex + 1] 접근이 리스트 범위를 벗어남(마지막 구간
    // 완료 직후엔 while 루프가 정상적으로 멈추지만, 그 다음 onPanUpdate 호출부터는 이 체크가
    // 없어서 RangeError가 났었음) - 여기서 막아줌
    if (_activeSegmentIndex >= kBearStitchSegmentCount) {
      setState(() => _isDragging = false);
      return;
    }

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
      });
      return;
    }

    setState(() {
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
      // 포인터 뗐으니 바늘도 같이 감춤
      _pointerLocalPosition = null;
    });
    if (_activeSegmentIndex >= kBearStitchSegmentCount) {
      // 9개 구간 다 완료되면 SUCCESS 배너 -> bear_success.png -> 암전 순서로 이어지는
      // 마무리 연출을 시작함. 그 끝에서 widget.onComplete() 호출됨
      _startCompletionSequence();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        // bear_arm_puzzle_scene.dart가 줌인을 다 끝낸 화면과 동일한 좌표계 - bearZoomFit()
        // 그대로 가져다 씀(min() 기반 레터박스). 예전엔 scaleX=w/290, scaleY=h/169를 독립적으로
        // 계산해서 크롭 영역이 화면을 딱 맞게 채운다고 가정했는데, 화면 비율이 크롭
        // 비율(290:169)이랑 다르면(모바일 세로 화면 등) 가로/세로가 다른 배율로 늘어나면서
        // 점/바늘/팔이 다 찌그러져 보이는 문제가 있었음. 지금은 레터박스라 크롭 영역 좌상단이
        // 화면 (0,0)이 아니라 (zoomFit.anchorX, zoomFit.anchorY)일 수 있음
        final BearZoomFit zoomFit = bearZoomFit(w, h);
        final double scaleX = zoomFit.scale;
        final double scaleY = zoomFit.scale;
        double wX(double localX) => zoomFit.anchorX + localX * scaleX;
        double wY(double localY) => zoomFit.anchorY + localY * scaleY;

        // 고해상도 원본을 화면에 필요한 만큼만 디코딩하도록 cacheWidth/cacheHeight를 계산.
        // 실제 렌더링될 논리 픽셀 크기 * devicePixelRatio(기기 실제 배율) 정도면 화질 손실
        // 없이 딱 필요한 만큼만 디코딩됨 - 원본 해상도가 아무리 높아도 메모리/디코딩 비용이
        // 이 크기로 고정됨
        final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        int cachePx(double logicalSize) =>
            (logicalSize * devicePixelRatio).round();

        // 곰돌이 팔/점/배경이랑 동일하게 scaleX(=zoomFit.scale)를 곱해야 함. 예전엔
        // kBearStitchNeedleSize를 스케일 안 곱하고 그대로 논리 픽셀 크기로 썼는데, 이러면
        // 화면마다 다른 배율로 확대되는 다른 요소들이랑 다르게 바늘만 항상 고정 크기로 보여서
        // PC(배율이 큼, 상대적으로 작아 보임)랑 모바일(배율이 작음, 상대적으로 커 보임)에서
        // 크기가 안 맞았음
        final double needleSize = kBearStitchNeedleSize * scaleX;
        final double needleHeight =
            needleSize * kBearStitchNeedleContentHeightRatio;

        // 9개 구간 다 완료된 뒤 마무리 연출(SUCCESS 배너/bear_success.png/암전) 중 하나라도
        // 떠있는 상태인지. diary_puzzle_scene.dart의 isPuzzleComplete랑 같은 용도 - 마무리
        // 연출이 시작되면 더 이상 드래그할 필요가 없으니 점/선판을 치워서 화면을 깔끔하게 함
        final bool isCompletionSequenceActive =
            _showSuccessBanner || _showBearSuccessImage || _showBlackout;

        // SUCCESS 배너 위치 계산용. 챕터1/2/3 미니게임들이 쓰는 874x507 캔버스
        // (kBearArmCanvasWidth/Height) 기준 - 크롭 좌표계(wX/wY)랑은 별개
        double rW(double px) => px * w / kBearArmCanvasWidth;
        double rH(double px) => px * h / kBearArmCanvasHeight;

        // 이 위젯은 이제 배경 없이 투명한 오버레이(점/선/바늘)만 담당함 - Container로 감싸서
        // 검은 배경을 깔지 않고 그냥 Stack만 반환해서, bear_arm_puzzle_scene.dart가 이미
        // 그려둔 배경(bear_bg+bear_hand)이 그대로 비쳐 보이게 함
        return Stack(
          children: [
            // 점/선을 그리는 판. 드래그 판정도 이 위에서 같이 처리
            if (!isCompletionSequenceActive)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) => _handlePanStart(
                    details,
                    scaleX,
                    scaleY,
                    zoomFit.anchorX,
                    zoomFit.anchorY,
                  ),
                  onPanUpdate: (details) => _handlePanUpdate(
                    details,
                    scaleX,
                    scaleY,
                    zoomFit.anchorX,
                    zoomFit.anchorY,
                  ),
                  onPanEnd: _handlePanEnd,
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _BearStitchPainter(
                      scaleX: scaleX,
                      scaleY: scaleY,
                      anchorX: zoomFit.anchorX,
                      anchorY: zoomFit.anchorY,
                      completedSegments: _completedSegments,
                    ),
                  ),
                ),
              ),

            // 바늘. 판정 결과(유효/무효 구간)랑 상관없이 포인터가 눌려있는 동안은 항상 그
            // 위치를 따라다님(_pointerLocalPosition). 성공 판정에 쓰는 _isDragging이랑은
            // 별개 상태. IgnorePointer로 감싸서 자기 자신이 GestureDetector의 드래그
            // 판정을 가로막지 않게 함
            if (_pointerLocalPosition != null)
              Positioned(
                // 중앙 정렬 안 하고 포인터 좌표를 그대로 좌상단 모서리로 씀 - 판정에 쓰는
                // _pointerLocalPosition 값 자체는 그대로라 구간/경로 판정에는 영향 없음
                left: wX(_pointerLocalPosition!.dx),
                top: wY(_pointerLocalPosition!.dy),
                width: needleSize,
                height: needleHeight,
                child: IgnorePointer(
                  // needle.png 원본 이미지는 위쪽 절반만 그림이 있고 아래쪽 절반은 투명
                  // 여백이라(kBearStitchNeedleContentHeightRatio 주석 참고), 원본 전체를
                  // needleSize 크기로 그린 다음 위쪽 절반만 잘라서 보여줌
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: needleSize,
                      maxWidth: needleSize,
                      minHeight: needleSize,
                      maxHeight: needleSize,
                      alignment: Alignment.topCenter,
                      child: Image.asset(
                        'assets/images/needle.png',
                        fit: BoxFit.contain,
                        cacheWidth: cachePx(needleSize),
                        cacheHeight: cachePx(needleSize),
                      ),
                    ),
                  ),
                ),
              ),

            // SUCCESS 배너. 9개 구간 다 완료되면 잠깐 떴다가 bear_success.png로 넘어감.
            // 챕터1/2/3 미니게임 성공 연출(diary_puzzle_scene.dart 등)이랑 동일한 이미지/
            // 위치 패턴
            if (_showSuccessBanner)
              Positioned(
                left: rW(kBearStitchSuccessBannerLeft),
                top: rH(kBearStitchSuccessBannerTop),
                width: rW(kBearStitchSuccessBannerWidth),
                height: rH(kBearStitchSuccessBannerHeight),
                child: Image.asset(
                  'assets/images/minigame_success.png',
                  fit: BoxFit.contain,
                ),
              ),

            // SUCCESS 배너 다음 결과 이미지. chapter3_diary_success_after.png 노출 시간
            // (kBearStitchSuccessAfterHoldDuration)이랑 동일한 시간 동안 화면 전체를 덮음
            if (_showBearSuccessImage)
              const Positioned.fill(
                child: Image(
                  image: AssetImage('assets/images/bear_success.png'),
                  fit: BoxFit.cover,
                ),
              ),

            // 결과 이미지 노출 끝나고 뜨는 암전. kBearStitchBlackoutHoldDuration만큼
            // 유지되다가 풀리면서 widget.onComplete()가 호출됨
            if (_showBlackout)
              const Positioned.fill(child: ColoredBox(color: Colors.black)),
          ],
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
    required this.anchorX,
    required this.anchorY,
    required this.completedSegments,
  });

  final double scaleX;
  final double scaleY;
  // 레터박스 중앙 정렬 오프셋. 화면 비율이 크롭 비율이랑 다르면 크롭 영역 좌상단이
  // 화면 (0,0)이 아닐 수 있어서 필요함
  final double anchorX;
  final double anchorY;
  final Set<int> completedSegments;

  Offset _toScreen(Offset local) =>
      Offset(anchorX + local.dx * scaleX, anchorY + local.dy * scaleY);

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
        oldDelegate.anchorX != anchorX ||
        oldDelegate.anchorY != anchorY ||
        oldDelegate.completedSegments.length != completedSegments.length;
  }
}
