// lib/features/chapter1/memory_flashback_scene.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';

enum _FlashbackStage {
  // memory_car_bumpy.gif만 조용히 보여주는 상태
  plain,
  // 구름들이 오른쪽 화면 밖에서 하나씩 슬라이드로 들어오는 상태
  cloudsEntering,
  carSmooth,
  parkArrival,
  parkKid,
}

enum _CloudEntryDirection { left, right }

class _CloudSpec {
  // 화면 비율 874x402 캔버스 기준, 구름이 최종적으로 멈추는 위치/크기
  final double left;
  final double top;
  final double width;
  final double height;
  // 같은 group끼리는 동시에 진입을 시작함 (group 번호가 클수록 늦게 시작)
  final int group;
  // 화면 어느 쪽 밖에서 슬라이드해 들어올지
  final _CloudEntryDirection from;
  // memory_cloud.png를 좌우반전해서 그릴지 여부
  final bool flipped;
  const _CloudSpec({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.group,
    required this.from,
    this.flipped = false,
  });
}

// 구름들이 멈추는 최종 위치/크기 목록. group이 같으면 동시에, 다르면 순서대로 들어옴
const List<_CloudSpec> _cloudSpecs = [
  _CloudSpec(
    left: 588,
    top: -43,
    width: 370,
    height: 250,
    group: 0,
    from: _CloudEntryDirection.right,
  ),
  _CloudSpec(
    left: -113,
    top: -27,
    width: 316,
    height: 214,
    group: 1,
    from: _CloudEntryDirection.left,
  ),
  _CloudSpec(
    left: 540,
    top: -22,
    width: 171,
    height: 116,
    group: 1,
    from: _CloudEntryDirection.right,
  ),
  _CloudSpec(
    left: 93,
    top: -53,
    width: 269,
    height: 182,
    group: 2,
    from: _CloudEntryDirection.left,
    flipped: true,
  ),
  _CloudSpec(
    left: 340,
    top: -35,
    width: 269,
    height: 182,
    group: 2,
    from: _CloudEntryDirection.right,
    flipped: true,
  ),
  _CloudSpec(
    left: 257,
    top: 43,
    width: 165,
    height: 112,
    group: 3,
    from: _CloudEntryDirection.left,
  ),
];

// car_bumpy.gif만 떠 있는 시간
const Duration _plainHoldDuration = Duration(milliseconds: 2500);
// 구름이 하나씩 들어오기 시작하는 간격
const Duration _cloudEntryStagger = Duration(milliseconds: 1000);
// 구름 한 개가 화면 밖에서 제자리까지 슬라이드해오는 데 걸리는 시간(천천히)
const Duration _cloudEntryDuration = Duration(milliseconds: 3000);
// 모든 구름이 들어온 뒤, 검은 반투명 배경 + 마지막 구름 힌트 전환까지의 지연시간
const Duration _cloudHintDelay = Duration(milliseconds: 800);

// 힌트 구름을 위치는 그대로 두고, 이만큼 드래그하면 치워진 것으로 처리 (실제 화면 px 기준)
const double _cloudDismissDragThreshold = 40.0;
// 구름이 치워질 때 작아지며 사라지는 애니메이션 시간
const Duration _cloudDismissAnimDuration = Duration(milliseconds: 250);
// 모든 구름을 다 치운 뒤 minigame_success를 띄워두는 시간. 이후 memory_car_smooth로 전환
const Duration _minigameSuccessHoldDuration = Duration(milliseconds: 800);
// success 다음에 이어지는 배경 전환 대기 시간들. carSmooth -> parkArrival -> parkKid 순서로 넘어가고
// parkKid까지 다 보여준 뒤에 onComplete가 호출됨
const Duration _carSmoothHoldDuration = Duration(milliseconds: 1600);
const Duration _parkArrivalHoldDuration = Duration(milliseconds: 2200);
const Duration _parkKidHoldDuration = Duration(milliseconds: 1500);

// "왼쪽으로 밀어라" 드래그 유도 박스/화살표 설정 (874x402 캔버스 기준 px)
const double _dragHintBoxLeft = 82;
const double _dragHintBoxTop = 88;
const double _dragHintBoxWidth = 200;
const double _dragHintBoxHeight = 32;
const double _dragHintArrowWidth = 12;
const double _dragHintArrowHeight = 12;
const double _dragHintArrowSpacing = 12;
// 그라데이션이 도달하는 최대 불투명도 (0~80%)
const double _dragHintGradientMaxOpacity = 0.8;
// 화살표가 한 칸(화살표 폭 + 간격)만큼 왼쪽으로 흘러가는 데 걸리는 시간
const Duration _dragHintArrowCycleDuration = Duration(milliseconds: 800);

// 구름 드래그 미니게임 안내 멘트. "먹구름을 드래그" 구간만 강조 표시
const String _cloudDragGuideTextBefore =
    '앗! 곧 비가 올 거 같아요.\n놀이공원에 무사히 도착할 수 있게 ';
const String _cloudDragGuideTextHighlight = '먹구름을 드래그';
const String _cloudDragGuideTextAfter = '해서 치워주세요!';
// 안내 멘트 박스를 화면 정중앙보다 살짝 위에 띄우기 위한 정렬값
const Alignment _cloudDragGuideAlignment = Alignment(0, 0.025);

class MemoryFlashbackScene extends StatefulWidget {
  const MemoryFlashbackScene({
    super.key,
    required this.onTemperatureIncrease,
    required this.onComplete,
  });

  final VoidCallback onTemperatureIncrease;
  final VoidCallback onComplete;

  @override
  State<MemoryFlashbackScene> createState() => _MemoryFlashbackSceneState();
}

class _MemoryFlashbackSceneState extends State<MemoryFlashbackScene>
    with SingleTickerProviderStateMixin {
  _FlashbackStage _stage = _FlashbackStage.plain;
  // 구름별로 화면 안으로 슬라이드가 시작됐는지 여부. 순서대로 하나씩 true가 됨
  late final List<bool> _cloudEntered = List.filled(_cloudSpecs.length, false);
  // 진입 애니메이션이 끝나 제자리에 멈췄는지 여부. true가 된 뒤로는 화면 크기가
  // 바뀌어도 다시 슬라이드하지 않고 즉시 재배치됨
  late final List<bool> _cloudSettled = List.filled(_cloudSpecs.length, false);
  // 모든 구름이 들어온 뒤, 검은 반투명 배경과 마지막 구름의 힌트 전환을 보여줄지 여부
  bool _showCloudHint = false;
  // 드래그 유도 화살표가 왼쪽으로 계속 흘러가는 애니메이션
  late final AnimationController _dragArrowController;
  // 구름별 드래그 제스처 누적 이동 거리 (일정 이상이면 치움 판정)
  late final List<Offset> _cloudDragAccum = List.filled(
    _cloudSpecs.length,
    Offset.zero,
  );
  // 구름별로 치워지는 페이드아웃 애니메이션이 시작됐는지 여부
  late final List<bool> _cloudDismissed = List.filled(
    _cloudSpecs.length,
    false,
  );
  // 구름별로 페이드아웃이 끝나 완전히 화면에서 빠졌는지 여부
  late final List<bool> _cloudGone = List.filled(_cloudSpecs.length, false);
  // 힌트(마지막) 구름이 치워지고 검은 배경/드래그 유도 박스/안내 문구까지 정리됐는지 여부.
  // 이 시점부터 나머지 구름들도 드래그로 치울 수 있게 됨
  bool _hintCleared = false;
  // 모든 구름을 다 치워서 minigame_success를 띄우고 있는지 여부
  bool _showMinigameSuccess = false;
  // 모든 구름 클리어 처리(성공 연출)를 중복 실행하지 않기 위한 플래그
  bool _allCloudsClearedTriggered = false;
  final List<Timer> _cloudDismissTimers = [];
  final List<Timer> _cloudEntryTimers = [];
  Timer? _stageTimer;
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    _dragArrowController = AnimationController(
      vsync: this,
      duration: _dragHintArrowCycleDuration,
    )..repeat();
    // car_bumpy.gif를 잠시 보여준 뒤 구름이 하나씩 들어오기 시작
    _stageTimer = Timer(_plainHoldDuration, () {
      if (!mounted) return;
      setState(() => _stage = _FlashbackStage.cloudsEntering);
      // 구름이 화면 밖 위치로 실제로 한 프레임 그려진 뒤에 진입을 시작해야
      // AnimatedPositioned가 그 위치에서부터 애니메이션함. 안 그러면 같은 프레임에
      // 두 setState가 묶여서 애니메이션 없이 바로 도착 위치로 나타나버림
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleCloudEntries();
      });
    });
  }

  // 구름들을 group 순서대로 진입시키고(같은 group은 동시에 진입),
  // 마지막 구름까지 다 들어오면 다음 단계로 넘어갈 준비를 함
  void _scheduleCloudEntries() {
    for (int i = 0; i < _cloudSpecs.length; i++) {
      final Duration delay = _cloudEntryStagger * _cloudSpecs[i].group;
      final Timer enterTimer = Timer(delay, () {
        if (!mounted) return;
        setState(() => _cloudEntered[i] = true);
        // 슬라이드가 실제로 끝나는 시점에 맞춰 "정착" 처리
        final Timer settleTimer = Timer(_cloudEntryDuration, () {
          if (!mounted) return;
          setState(() => _cloudSettled[i] = true);
        });
        _cloudEntryTimers.add(settleTimer);
      });
      _cloudEntryTimers.add(enterTimer);
    }
    final int maxGroup = _cloudSpecs
        .map((spec) => spec.group)
        .reduce((a, b) => a > b ? a : b);
    final Duration allEnteredAt =
        _cloudEntryStagger * maxGroup + _cloudEntryDuration;
    // 모든 구름이 들어오고 1500ms 뒤: 검은 반투명 배경이 깔리고 마지막 구름이
    // cloud_tutorial_hint로 바뀌어 그 배경 위에 남음
    final Timer hintTimer = Timer(allEnteredAt + _cloudHintDelay, () {
      if (!mounted) return;
      setState(() => _showCloudHint = true);
    });
    _cloudEntryTimers.add(hintTimer);
  }

  // 이미지 프리캐싱: 첫 빌드 시점에 한 번만 실행
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/memory_car_bumpy.gif',
        'assets/images/memory_car_smooth.gif',
        'assets/images/memory_park_arrival.gif',
        'assets/images/memory_park_kid.png',
        'assets/images/memory_cloud.png',
        'assets/images/cloud_tutorial_hint.png',
        'assets/images/cloud_drag_arrow.png',
        'assets/images/minigame_success.png',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    for (final timer in _cloudEntryTimers) {
      timer.cancel();
    }
    for (final timer in _cloudDismissTimers) {
      timer.cancel();
    }
    _dragArrowController.dispose();
    super.dispose();
  }

  // 배경 이미지 경로를 현재 단계에 맞춰 반환
  String _backgroundAssetFor(_FlashbackStage stage) {
    switch (stage) {
      case _FlashbackStage.plain:
      case _FlashbackStage.cloudsEntering:
        return 'assets/images/memory_car_bumpy.gif';
      case _FlashbackStage.carSmooth:
        return 'assets/images/memory_car_smooth.gif';
      case _FlashbackStage.parkArrival:
        return 'assets/images/memory_park_arrival.gif';
      case _FlashbackStage.parkKid:
        return 'assets/images/memory_park_kid.png';
    }
  }

  // 구름 하나를 진입 애니메이션과 함께 배치. 마지막 구름은 힌트 전환 시점이 되면
  // memory_cloud.png 대신 cloud_tutorial_hint.png로 바뀌면서 드래그로 치울 수 있게 되고,
  // 힌트가 끝난 뒤로는 나머지 구름들도 같은 방식으로 드래그해서 치울 수 있음
  Widget _buildCloud(
    int i, {
    required double w,
    required double h,
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    final _CloudSpec spec = _cloudSpecs[i];
    final bool isLast = i == _cloudSpecs.length - 1;
    final bool isHintCloud = isLast && _showCloudHint && !_hintCleared;
    final bool isDraggable = isHintCloud || (_hintCleared && !isLast);
    final double cloudW = rW(spec.width);
    final double cloudH = rH(spec.height);

    if (isDraggable) {
      // 드래그 가능한 구름은 위치를 고정해두고, 일정 거리 이상 드래그하면 페이드아웃되며 사라짐
      // (구름이 손가락을 따라 움직이는 건 어색해서 위치는 고정)
      return Positioned(
        key: ValueKey('cloud_drag_$i'),
        left: rW(spec.left),
        top: rH(spec.top),
        width: cloudW,
        height: cloudH,
        child: IgnorePointer(
          ignoring: _cloudDismissed[i],
          child: GestureDetector(
            onPanStart: (_) => _cloudDragAccum[i] = Offset.zero,
            onPanUpdate: (details) {
              if (_cloudDismissed[i]) return;
              _cloudDragAccum[i] += details.delta;
              if (_cloudDragAccum[i].distance >= _cloudDismissDragThreshold) {
                setState(() => _cloudDismissed[i] = true);
                final Timer dismissTimer = Timer(_cloudDismissAnimDuration, () {
                  if (!mounted) return;
                  _onCloudDismissSettled(i, isLast: isLast);
                });
                _cloudDismissTimers.add(dismissTimer);
              }
            },
            child: AnimatedOpacity(
              opacity: _cloudDismissed[i] ? 0.0 : 1.0,
              duration: _cloudDismissAnimDuration,
              child: isLast
                  ? Image.asset(
                      'assets/images/cloud_tutorial_hint.png',
                      fit: BoxFit.contain,
                    )
                  : Transform.flip(
                      flipX: spec.flipped,
                      child: Image.asset(
                        'assets/images/memory_cloud.png',
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return AnimatedPositioned(
      key: ValueKey('cloud_$i'),
      // 정착 전엔 천천히 슬라이드, 정착 후엔 화면 크기 변경 시 즉시 재배치
      duration: _cloudSettled[i] ? Duration.zero : _cloudEntryDuration,
      curve: Curves.easeOut,
      // 시작 위치: 지정된 방향의 화면 밖. 들어온 뒤: 지정된 최종 위치
      left: _cloudEntered[i]
          ? rW(spec.left)
          : (spec.from == _CloudEntryDirection.right ? w + cloudW : -cloudW),
      top: rH(spec.top),
      width: cloudW,
      height: cloudH,
      child: Transform.flip(
        flipX: spec.flipped,
        child: Image.asset(
          'assets/images/memory_cloud.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // 구름 하나의 치우기 애니메이션이 끝났을 때 처리: 완전히 제거하고, 힌트 구름이면
  // 검은 배경/드래그 유도 박스/안내 문구도 정리. 모든 구름이 다 치워지면 성공 연출 시작
  void _onCloudDismissSettled(int i, {required bool isLast}) {
    setState(() {
      _cloudGone[i] = true;
      if (isLast) _hintCleared = true;
    });
    final bool allGone = _cloudGone.every((gone) => gone);
    if (allGone && !_allCloudsClearedTriggered) {
      _allCloudsClearedTriggered = true;
      widget.onTemperatureIncrease();
      setState(() => _showMinigameSuccess = true);
      final Timer successTimer = Timer(_minigameSuccessHoldDuration, () {
        if (!mounted) return;
        setState(() {
          _showMinigameSuccess = false;
          _stage = _FlashbackStage.carSmooth;
        });
        // 여기서부터는 사용자 입력 없이 배경만 순서대로 넘기면서 마지막에 onComplete를 부르면 됨
        final Timer carSmoothTimer = Timer(_carSmoothHoldDuration, () {
          if (!mounted) return;
          setState(() => _stage = _FlashbackStage.parkArrival);
          final Timer parkArrivalTimer = Timer(_parkArrivalHoldDuration, () {
            if (!mounted) return;
            setState(() => _stage = _FlashbackStage.parkKid);
            final Timer parkKidTimer = Timer(_parkKidHoldDuration, () {
              if (!mounted) return;
              widget.onComplete();
            });
            _cloudDismissTimers.add(parkKidTimer);
          });
          _cloudDismissTimers.add(parkArrivalTimer);
        });
        _cloudDismissTimers.add(carSmoothTimer);
      });
      _cloudDismissTimers.add(successTimer);
    }
  }

  // 드래그 유도 박스: 흰색 그라데이션(왼쪽 0% -> 오른쪽 80%) 배경 위에
  // 왼쪽을 가리키는 화살표(cloud_drag_arrow.png)가 간격을 유지한 채 계속 왼쪽으로 흘러감
  Widget _buildDragHintBox({
    required double Function(double) rW,
    required double Function(double) rH,
  }) {
    final double boxLeft = rW(_dragHintBoxLeft);
    final double boxTop = rH(_dragHintBoxTop);
    final double boxWidth = rW(_dragHintBoxWidth);
    final double boxHeight = rH(_dragHintBoxHeight);
    final double arrowW = rW(_dragHintArrowWidth);
    final double arrowH = rH(_dragHintArrowHeight);
    final double step = arrowW + rW(_dragHintArrowSpacing);
    // 화살표가 흘러가며 빠져나가도 끊김 없이 이어지도록, 박스를 채우고 남을 만큼 여분으로 더 그림
    final int arrowCount = (boxWidth / step).ceil() + 1;

    return Positioned(
      left: boxLeft,
      top: boxTop,
      width: boxWidth,
      height: boxHeight,
      // IgnorePointer는 Positioned 바깥이 아니라 안쪽에 있어야 함. Positioned는 Stack의
      // 직계 자식이어야 위치/크기가 적용되는데, 바깥에 IgnorePointer를 두면 그 조건이
      // 깨져서 박스가 위치/크기 지정 없이 화면 전체로 확장돼버림
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              // 흰색 그라데이션 박스: 왼쪽 0% -> 오른쪽 80%
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(
                          alpha: _dragHintGradientMaxOpacity,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _dragArrowController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(-step * _dragArrowController.value, 0),
                  child: child,
                ),
                child: Stack(
                  children: [
                    for (int i = 0; i < arrowCount; i++)
                      Positioned(
                        left: step * i,
                        top: (boxHeight - arrowH) / 2,
                        width: arrowW,
                        height: arrowH,
                        child: Image.asset(
                          'assets/images/cloud_drag_arrow.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 화면 크기에 맞춰 배경 이미지와 구름을 표시
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        double rW(double px) => (px / 874) * w;
        double rH(double px) => (px / 402) * h;

        final String backgroundAsset = _backgroundAssetFor(_stage);

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Image.asset(
                    backgroundAsset,
                    key: ValueKey(backgroundAsset),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              if (_stage == _FlashbackStage.cloudsEntering) ...[
                // 마지막 구름을 제외한 나머지는 반투명 배경 아래에 깔림. 치운 구름은 건너뜀
                for (int i = 0; i < _cloudSpecs.length - 1; i++)
                  if (!_cloudGone[i])
                    _buildCloud(i, w: w, h: h, rW: rW, rH: rH),
                if (_showCloudHint && !_hintCleared)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: Color(0x8C000000)),
                    ),
                  ),
                // 드래그 유도 박스는 검은 배경 위, 마지막 구름(cloud_tutorial_hint)보다는 아래
                if (_showCloudHint && !_hintCleared)
                  _buildDragHintBox(rW: rW, rH: rH),
                // 마지막 구름은 항상 최상위 레이어: 반투명 배경과 드래그 유도 박스 위에 그려짐.
                // 일정 이상 드래그해서 치우는 애니메이션까지 끝나면 완전히 사라짐
                if (!_cloudGone[_cloudSpecs.length - 1])
                  _buildCloud(
                    _cloudSpecs.length - 1,
                    w: w,
                    h: h,
                    rW: rW,
                    rH: rH,
                  ),
                // 게임 안내 멘트. 다른 튜토리얼 안내와 동일하게 tutorial_dialogue_box 사용.
                // CenteredDialogueBox는 다른 화면들과 공유하는 정렬(0, 0.2)을 쓰므로,
                // 여기서는 화면 중앙보다 살짝 위로 띄우기 위해 DialogueBoxFrame을 직접 배치
                if (_showCloudHint && !_hintCleared)
                  Align(
                    alignment: _cloudDragGuideAlignment,
                    child: DialogueBoxFrame(
                      textWidget: Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                          children: [
                            const TextSpan(text: _cloudDragGuideTextBefore),
                            const TextSpan(
                              text: _cloudDragGuideTextHighlight,
                              style: TextStyle(
                                color: Color(0xFFFF7100),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: _cloudDragGuideTextAfter),
                          ],
                        ),
                        style: dialogueTextStyle(rW),
                      ),
                      rW: rW,
                      rH: rH,
                    ),
                  ),
                // 모든 구름을 다 치워서 minigame_success를 띄우는 연출. 이후 memory_car_smooth로 전환
                if (_showMinigameSuccess)
                  Positioned(
                    left: rW(158),
                    top: rH(43),
                    width: rW(557),
                    height: rH(129),
                    child: Image.asset(
                      'assets/images/minigame_success.png',
                      width: rW(557),
                      height: rH(129),
                      fit: BoxFit.contain,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
