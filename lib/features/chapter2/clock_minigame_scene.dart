// lib/features/chapter2/clock_minigame_scene.dart

// 챕터2: 빵 먹은 뒤 이어지는 시계 맞추기 미니게임. 암전 -> 인트로 -> 시계 등장 -> 대사창 ->
// 드래그 미니게임 -> 성공 연출 -> 암전 -> onComplete 순서로 진행

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';

enum _ClockStage {
  // 암전 대기
  blackoutStart,
  // 인트로 이미지 노출
  intro,
  // 시계 등장, 대사창 뜨기 전
  clockIdle,
  // 대사창 노출. 탭하면 사라지고 미니게임 시작
  dialogue,
  // 드래그로 시간 맞추는 중
  minigame,
  // 성공 배너 노출
  success,
  // 성공 연출 1번째 컷
  successPhoto1,
  // 성공 연출 2번째 컷
  successPhoto2,
  // 마지막 암전, 이후 onComplete 호출
  blackoutEnd,
}

// 지금 드래그 중인 바늘 구분
enum _ClockHand { hour, minute }

// 단계별 대기 시간
const Duration _initialBlackoutHoldDuration = Duration(milliseconds: 400);
const Duration _introHoldDuration = Duration(milliseconds: 2000);
const Duration _clockAppearToDialogueDelay = Duration(milliseconds: 1000);
const Duration _successBannerHoldDuration = Duration(milliseconds: 1200);
const Duration _successPhoto1HoldDuration = Duration(milliseconds: 1800);
const Duration _successPhoto2HoldDuration = Duration(milliseconds: 1800);
const Duration _finalBlackoutHoldDuration = Duration(milliseconds: 800);

// clock_minigame_bg.png 원본 비율(3496x1796)을 유지한 캔버스 크기. 가로는 874로 고정하고
// 세로는 원본 비율 그대로 계산함(874 * 1796/3496 = 449). 예전엔 874x402(다른 화면들과
// 맞춘 임의의 비율) 박스에 BoxFit.fill로 그려서 이미지가 가로로 눌려 찌그러져 보였음
const double _bgCanvasWidth = 874;
const double _bgCanvasHeight = 449;

// 시계 중심 좌표 (874x449 캔버스 기준). 예전 874x402 캔버스에서 잡았던 상대 위치
// (가로 48.3%, 세로 44.0%)를 그대로 유지해서 새 캔버스 크기에 맞게 다시 계산한 값
const double _clockCenterXPx = 422;
const double _clockCenterYPx = 197.7;
// 시침(clock_hour_hand.png, 원본 96x488)과 분침(clock_minute_hand.png, 원본 720x96)은
// 원본 크기 자체가 서로 다르게 그려져 있음. 예전엔 둘 다 같은 180x180 정사각 박스에
// BoxFit.contain으로 각각 맞춰서, 짧아야 할 시침이 분침과 똑같은 길이(180)로 늘어나 보였음.
// 이제 원본 픽셀에 동일한 배율(_handPxScale)만 곱해서 실제 상대 크기 그대로 유지함
const double _hourHandNativeWidth = 96;
const double _hourHandNativeHeight = 488;
const double _minuteHandNativeWidth = 720;
const double _minuteHandNativeHeight = 96;
// 분침 길이(720)가 예전 180과 같아지도록 잡은 공통 배율. 이 값 하나로 두 바늘의
// 상대적인 길이/두께 비율이 그대로 유지됨
const double _handPxScale = 180 / _minuteHandNativeWidth;
const double _clockCenterDotSizePx = 40;
// 시침/분침 그림의 실제 회전축이 이미지 중심에서 벗어난 만큼의 보정값(worldScale 단위).
// Transform.rotate의 origin으로 회전축 자체를 옮겨서 각도가 바뀌어도 안 어긋나게 함.
// 분침은 예전 배율(180/720=0.25)이 그대로라 -78.1 유지. 시침은 배율이 180/488(≈0.369)에서
// _handPxScale(0.25)로 바뀌어서, 예전 실측값(72.1)을 새 배율 비율만큼 다시 계산함
// (72.1 * (0.25 / (180/488)) ≈ 48.9)
const double _hourHandOffsetX = 0;
const double _hourHandOffsetY = 48.9;
const double _minuteHandOffsetX = -78.1;
const double _minuteHandOffsetY = 0;
// 그림이 원래 그려진 방향과 12시 방향의 차이 보정값. Transform.rotate angle에 그대로 더해서
// 적용함. 시침은 이미 12시 방향으로 그려져 있어 0, 분침은 3시 방향으로 그려져 있어 -90
const double _hourHandBaseRotationOffsetDeg = 0.0;
const double _minuteHandBaseRotationOffsetDeg = -90.0;
// 드래그 히트박스 크기. 분침의 회전축~끝 거리(90+78.1=168.1)가 반경보다 커야 분침 끝이
// 히트박스 밖으로 안 벗어남(168.1*2=336.2보다 넉넉하게 350로 잡음)
const double _clockDragHitboxSizePx = 350;

// 시침 시작 각도(1시 위치). 분침이랑 독립적으로 드래그되는 state의 초기값으로 씀
const double _clockBaseHourAngleDeg = 30.0;
// 시침 스냅 단위(1시간=30도). 분침 한 바퀴당 시침 자동 이동량으로도 씀
const double _hourSnapStepDeg = 30.0;
// 분침 스냅 단위. 시침처럼 자유롭게 안 움직이고 눈금 단위로 딱딱 맞게 움직임
const double _minuteSnapStepDeg = 30.0;

// 목표 시간: 7시 정각. 시침은 정확히 210도(7시)에 스냅, 분침은 0도(12시) 근처 ±5도까지 허용
// (355도~360도, 0도~5도. wraparound 처리 필요)
const double _targetHourAngleDeg = 210.0;
const double _targetMinuteValue = 0.0;
const double _minuteToleranceValue = 5.0;

// 대사창에 표시할 텍스트
const String _clockDialogueText = '채온이가 일어날 시간이에요!\n시침과 분침을 드래그하여 시간을 7시로 맞춰주세요.';

// minigame_success 배너 위치/크기. 챕터1 구름 게임/챕터2 빵만들기 게임과 동일 자산 재사용
const double _successBannerLeft = 158;
const double _successBannerTop = 43;
const double _successBannerWidth = 557;
const double _successBannerHeight = 129;

class ClockMinigameScene extends StatefulWidget {
  const ClockMinigameScene({super.key, required this.onComplete});

  // 성공 연출 끝나고 호출됨. 다음 화면 전환은 호출부 책임
  final VoidCallback onComplete;

  @override
  State<ClockMinigameScene> createState() => _ClockMinigameSceneState();
}

class _ClockMinigameSceneState extends State<ClockMinigameScene> {
  _ClockStage _stage = _ClockStage.blackoutStart;
  // 분침 각도(0도=12시, 시계방향 증가). 1:30에서 시작
  double _minuteAngleDeg = 180;
  // 시침 각도. 분침과 독립적인 state로 관리, 1시 위치에서 시작
  double _hourAngleDeg = _clockBaseHourAngleDeg;
  // 지금 드래그 중인 바늘. onPanStart에서 한 번만 판정
  _ClockHand? _draggingHand;
  // 분침의 누적 회전량(wraparound 보정한 델타 누적, 12시=0도 기준 절대 회전량).
  // 360도 단위로 시침 자동 이동에 씀. 분침이 0(30분이 아니라 0분/12시)에 도달했을 때
  // 시침이 움직여야 하므로, 시작 각도(_minuteAngleDeg)와 동일하게 180에서 시작함
  // (0에서 시작하면 시침이 "30분→다시 30분"까지 꽉 채운 360도를 돌아야 움직여서
  // 실제 시계보다 절반 늦게 움직이는 문제가 있었음)
  double _minuteRotationAccumulator = 180;
  // 위 누적값 기준 시침을 자동 이동시킨 횟수
  int _completedMinuteTurns = 0;
  // 성공 처리 후 더 이상 드래그로 안 바뀌게 막는 플래그
  bool _isMinigameSolved = false;
  final List<Timer> _timers = [];
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    final Timer blackoutTimer = Timer(_initialBlackoutHoldDuration, () {
      if (!mounted) return;
      setState(() => _stage = _ClockStage.intro);
      final Timer introTimer = Timer(_introHoldDuration, () {
        if (!mounted) return;
        setState(() => _stage = _ClockStage.clockIdle);
        final Timer dialogueDelayTimer = Timer(_clockAppearToDialogueDelay, () {
          if (!mounted) return;
          setState(() => _stage = _ClockStage.dialogue);
        });
        _timers.add(dialogueDelayTimer);
      });
      _timers.add(introTimer);
    });
    _timers.add(blackoutTimer);
  }

  // 이미지 프리캐싱, 최초 1회만
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/chapter2_clock_intro.png',
        'assets/images/clock_minigame_bg.png',
        'assets/images/clock_hour_hand.png',
        'assets/images/clock_minute_hand.png',
        'assets/images/clock_center_dot.png',
        'assets/images/chapter2_clock_success_1.png',
        'assets/images/chapter2_clock_success_2.png',
        'assets/images/minigame_success.png',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  // 대사창 탭하면 닫고 미니게임 시작
  void _dismissDialogueAndStartMinigame() {
    setState(() => _stage = _ClockStage.minigame);
  }

  // 중심 기준 로컬 좌표의 각도 (12시=0도, 시계방향)
  double _angleFromCenterDeg(Offset localPosition, double boxSize) {
    final double dx = localPosition.dx - boxSize / 2;
    final double dy = localPosition.dy - boxSize / 2;
    final double rad = math.atan2(dx, -dy);
    final double deg = rad * 180 / math.pi;
    return (deg + 360) % 360;
  }

  // 주어진 각도의 바늘 끝점 좌표. 드래그 시작 시 바늘 판정에 씀
  Offset _handEndpoint(double angleDeg, double boxSize, double handRadius) {
    final double rad = angleDeg * math.pi / 180;
    final double centerLocal = boxSize / 2;
    return Offset(
      centerLocal + handRadius * math.sin(rad),
      centerLocal - handRadius * math.cos(rad),
    );
  }

  // 터치 지점이 더 가까운 바늘을 드래그 대상으로 고정
  void _handlePanStart(
    Offset localPosition,
    double boxSize,
    double hourHandRadius,
    double minuteHandRadius,
  ) {
    if (_isMinigameSolved) return;
    final Offset hourEnd = _handEndpoint(
      _hourAngleDeg,
      boxSize,
      hourHandRadius,
    );
    final Offset minuteEnd = _handEndpoint(
      _minuteAngleDeg,
      boxSize,
      minuteHandRadius,
    );
    final double distToHour = (localPosition - hourEnd).distance;
    final double distToMinute = (localPosition - minuteEnd).distance;
    _draggingHand = distToHour <= distToMinute
        ? _ClockHand.hour
        : _ClockHand.minute;
    _handleClockDrag(localPosition, boxSize);
  }

  // 잡고 있는 바늘 각도 갱신 후 성공 여부 체크
  void _handleClockDrag(Offset localPosition, double boxSize) {
    if (_isMinigameSolved || _draggingHand == null) return;
    final double newAngle = _angleFromCenterDeg(localPosition, boxSize);
    if (_draggingHand == _ClockHand.minute) {
      _applyMinuteDrag(newAngle);
    } else {
      _applyHourDrag(newAngle);
    }
    _checkMinigameSuccess();
  }

  // 분침을 6도(1분) 단위로 스냅 + 한 바퀴 돌 때마다 시침 30도 자동 이동
  void _applyMinuteDrag(double newAngle) {
    final double snappedAngle =
        (newAngle / _minuteSnapStepDeg).round() * _minuteSnapStepDeg % 360;
    double delta = snappedAngle - _minuteAngleDeg;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    final double newAccumulator = _minuteRotationAccumulator + delta;
    final int newTurns = (newAccumulator / 360).truncate();
    final int turnDelta = newTurns - _completedMinuteTurns;
    setState(() {
      _minuteAngleDeg = snappedAngle;
      _minuteRotationAccumulator = newAccumulator;
      _completedMinuteTurns = newTurns;
      if (turnDelta != 0) {
        _hourAngleDeg = (_hourAngleDeg + turnDelta * _hourSnapStepDeg) % 360;
      }
    });
  }

  // 시침을 30도 단위로 스냅
  void _applyHourDrag(double newAngle) {
    final double snapped =
        (newAngle / _hourSnapStepDeg).round() * _hourSnapStepDeg;
    setState(() => _hourAngleDeg = snapped % 360);
  }

  // 시침 7시 스냅 + 분침 0도 근처 허용범위 둘 다 맞으면 성공 처리
  void _checkMinigameSuccess() {
    if (_isMinigameSolved) return;
    final double hourAngle = _hourAngleDeg % 360;
    final bool isHourAtTarget = (hourAngle - _targetHourAngleDeg).abs() < 0.01;
    if (!isHourAtTarget) return;

    final double minuteAngle = _minuteAngleDeg % 360;
    final double minuteDiff = (minuteAngle - _targetMinuteValue).abs() % 360;
    final double minuteCircularDiff = minuteDiff > 180
        ? 360 - minuteDiff
        : minuteDiff;
    final bool isMinuteWithinTolerance =
        minuteCircularDiff <= _minuteToleranceValue;
    if (!isMinuteWithinTolerance) return;

    _isMinigameSolved = true;
    setState(() => _stage = _ClockStage.success);
    final Timer successTimer = Timer(_successBannerHoldDuration, () {
      if (!mounted) return;
      setState(() => _stage = _ClockStage.successPhoto1);
      final Timer photo1Timer = Timer(_successPhoto1HoldDuration, () {
        if (!mounted) return;
        setState(() => _stage = _ClockStage.successPhoto2);
        final Timer photo2Timer = Timer(_successPhoto2HoldDuration, () {
          if (!mounted) return;
          setState(() => _stage = _ClockStage.blackoutEnd);
          final Timer finalBlackoutTimer = Timer(
            _finalBlackoutHoldDuration,
            () {
              if (!mounted) return;
              widget.onComplete();
            },
          );
          _timers.add(finalBlackoutTimer);
        });
        _timers.add(photo2Timer);
      });
      _timers.add(photo1Timer);
    });
    _timers.add(successTimer);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        double rW(double px) => (px / 874) * w;
        double rH(double px) => (px / 402) * h;

        // 배경이 항상 화면을 빈틈없이 꽉 채우도록, 가로/세로 중 더 많이 확대해야 하는 쪽
        // 기준으로 스케일함(cover). 가로 기준(w/874)만 쓰면 창을 세로로 늘렸을 때 계산된
        // 배경 높이가 실제 화면 높이보다 작아져서 아래쪽에 빈 공간이 생겼음.
        // (가로/세로에 같은 배율을 써야 시계 바늘이 회전할 때 안 찌그러짐)
        final double worldScale = (w / _bgCanvasWidth) > (h / _bgCanvasHeight)
            ? (w / _bgCanvasWidth)
            : (h / _bgCanvasHeight);
        // 세로가 남으면(원래 케이스) 위쪽 정렬 유지, 가로가 남으면(세로로 긴 창) 좌우를
        // 대칭으로 잘라냄
        final double worldOffsetX = (w - _bgCanvasWidth * worldScale) / 2;
        const double worldOffsetY = 0;
        double wX(double px) => worldOffsetX + px * worldScale;
        double wY(double px) => worldOffsetY + px * worldScale;
        double wSize(double px) => px * worldScale;

        final bool showClockFace =
            _stage == _ClockStage.clockIdle ||
            _stage == _ClockStage.dialogue ||
            _stage == _ClockStage.minigame ||
            _stage == _ClockStage.success;

        // 시침/분침은 원본 종횡비를 그대로 유지한 채, 공통 배율(_handPxScale)만 적용해서
        // 서로 다른 크기로 렌더링함
        final double hourHandW = wSize(_hourHandNativeWidth * _handPxScale);
        final double hourHandH = wSize(_hourHandNativeHeight * _handPxScale);
        final double minuteHandW = wSize(_minuteHandNativeWidth * _handPxScale);
        final double minuteHandH = wSize(
          _minuteHandNativeHeight * _handPxScale,
        );
        final double dotSize = wSize(_clockCenterDotSizePx);
        final double hitboxSize = wSize(_clockDragHitboxSizePx);
        final double centerX = wX(_clockCenterXPx);
        final double centerY = wY(_clockCenterYPx);

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 인트로 이미지
              if (_stage == _ClockStage.intro)
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/chapter2_clock_intro.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),

              if (showClockFace) ...[
                // 1층: 시계 배경
                Positioned(
                  left: worldOffsetX,
                  top: worldOffsetY,
                  width: wSize(_bgCanvasWidth),
                  height: wSize(_bgCanvasHeight),
                  child: Image.asset(
                    'assets/images/clock_minigame_bg.png',
                    fit: BoxFit.fill,
                  ),
                ),
                // 2층: 시침. pivotOffset + baseRotationOffsetDeg 보정 적용
                Positioned(
                  left: centerX - hourHandW / 2 - wSize(_hourHandOffsetX),
                  top: centerY - hourHandH / 2 - wSize(_hourHandOffsetY),
                  width: hourHandW,
                  height: hourHandH,
                  child: Transform.rotate(
                    angle:
                        (_hourAngleDeg + _hourHandBaseRotationOffsetDeg) *
                        math.pi /
                        180,
                    origin: Offset(
                      wSize(_hourHandOffsetX),
                      wSize(_hourHandOffsetY),
                    ),
                    child: Image.asset(
                      'assets/images/clock_hour_hand.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // 2층: 분침. 동일한 보정 적용
                Positioned(
                  left: centerX - minuteHandW / 2 - wSize(_minuteHandOffsetX),
                  top: centerY - minuteHandH / 2 - wSize(_minuteHandOffsetY),
                  width: minuteHandW,
                  height: minuteHandH,
                  child: Transform.rotate(
                    angle:
                        (_minuteAngleDeg + _minuteHandBaseRotationOffsetDeg) *
                        math.pi /
                        180,
                    origin: Offset(
                      wSize(_minuteHandOffsetX),
                      wSize(_minuteHandOffsetY),
                    ),
                    child: Image.asset(
                      'assets/images/clock_minute_hand.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // 3층: 중앙 동그라미
                Positioned(
                  left: centerX - dotSize / 2,
                  top: centerY - dotSize / 2,
                  width: dotSize,
                  height: dotSize,
                  child: Image.asset(
                    'assets/images/clock_center_dot.png',
                    fit: BoxFit.contain,
                  ),
                ),
                // 미니게임 히트박스: 시침/분침 공용, onPanStart에서 어느 바늘인지 판정
                if (_stage == _ClockStage.minigame)
                  Positioned(
                    left: centerX - hitboxSize / 2,
                    top: centerY - hitboxSize / 2,
                    width: hitboxSize,
                    height: hitboxSize,
                    child: GestureDetector(
                      onPanStart: (details) => _handlePanStart(
                        details.localPosition,
                        hitboxSize,
                        // 각 바늘의 중심(회전축)에서 실제 끝(뾰족한 쪽)까지의 거리.
                        // 회전축이 이미지 중심에서 벗어난 만큼(_hourHandOffsetY 등) 더해줘야
                        // 이미지 크기에 딱 맞는 끝점이 나옴
                        hourHandH / 2 + wSize(_hourHandOffsetY).abs(),
                        minuteHandW / 2 + wSize(_minuteHandOffsetX).abs(),
                      ),
                      onPanUpdate: (details) =>
                          _handleClockDrag(details.localPosition, hitboxSize),
                      onPanEnd: (_) => _draggingHand = null,
                      onPanCancel: () => _draggingHand = null,
                    ),
                  ),
              ],

              // 대사창. 검은 반투명(50%) 배경 위에 뜨고, 탭하면 사라지고 미니게임이 활성화됨
              if (_stage == _ClockStage.dialogue)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissDialogueAndStartMinigame,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: CenteredDialogueBox(
                        textWidget: Text(
                          _clockDialogueText,
                          textAlign: TextAlign.center,
                          style: dialogueTextStyle(rW),
                        ),
                        rW: rW,
                        rH: rH,
                      ),
                    ),
                  ),
                ),

              // 성공 배너. 챕터1 구름 게임/빵만들기 게임이랑 동일한 자산·위치 재사용
              if (_stage == _ClockStage.success)
                Positioned(
                  left: rW(_successBannerLeft),
                  top: rH(_successBannerTop),
                  width: rW(_successBannerWidth),
                  height: rH(_successBannerHeight),
                  child: Image.asset(
                    'assets/images/minigame_success.png',
                    width: rW(_successBannerWidth),
                    height: rH(_successBannerHeight),
                    fit: BoxFit.contain,
                  ),
                ),

              if (_stage == _ClockStage.successPhoto1)
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/chapter2_clock_success_1.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),

              if (_stage == _ClockStage.successPhoto2)
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/chapter2_clock_success_2.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
