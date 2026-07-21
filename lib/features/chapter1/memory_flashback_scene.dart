// lib/features/chapter1/memory_flashback_scene.dart

import 'dart:async';
import 'package:flutter/material.dart';

enum _FlashbackStage {
  tutorial,
  carBumpyClouds,
  success,
  carSmooth,
  parkArrival,
  parkKid,
}

class _CloudSpec {
  final double left;
  final double top;
  final double width;
  const _CloudSpec({
    required this.left,
    required this.top,
    required this.width,
  });
}

// 구름 위치와 크기 사양. 화면 비율이 874x402 기준임. 화면 상단에 촘촘하게 겹쳐서 배치
const List<_CloudSpec> _cloudSpecs = [
  _CloudSpec(left: 10, top: 15, width: 190),
  _CloudSpec(left: 160, top: 55, width: 170),
  _CloudSpec(left: 300, top: 5, width: 210),
  _CloudSpec(left: 480, top: 50, width: 180),
  _CloudSpec(left: 630, top: 10, width: 200),
  _CloudSpec(left: 550, top: 120, width: 190),
];

// memory_cloud.png 원본 비율(370x250)
const double _cloudAspect = 370 / 250;

// 구름 드래그 판정 거리(px). 튜토리얼 구름과 실제 미니게임 구름이 공유
const double _dragDismissThreshold = 20.0;

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

// 구름을 드래그해 제거하는 미니게임. 모든 구름 제거 시 성공 메시지 표시 후 다음 단계로 진행
class _MemoryFlashbackSceneState extends State<MemoryFlashbackScene> {
  _FlashbackStage _stage = _FlashbackStage.tutorial;
  int _clearedCloudCount = 0;
  Timer? _stageTimer;
  bool _imagesPrecached = false;

  // 튜토리얼 구름 드래그 누적 거리
  Offset _tutorialDragAccum = Offset.zero;

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
        'assets/images/minigame_success.png',
        'assets/images/cloud_tutorial_hint.png',
        'assets/images/cloud_drag_arrow.png',
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  // 튜토리얼 구름을 짧게 드래그하면 암전+하이라이트+화살표를 애니메이션 없이 즉시 치우고 실제 미니게임으로 전환
  void _onTutorialPanStart(DragStartDetails details) {
    _tutorialDragAccum = Offset.zero;
  }

  void _onTutorialPanUpdate(DragUpdateDetails details) {
    _tutorialDragAccum += details.delta;
    if (_tutorialDragAccum.distance >= _dragDismissThreshold) {
      setState(() => _stage = _FlashbackStage.carBumpyClouds);
    }
  }

  // 구름 하나가 사라질 때마다 호출됨. 모든 구름이 사라지면 다음 단계로 진행
  void _onCloudCleared() {
    _clearedCloudCount++;
    if (_clearedCloudCount >= _cloudSpecs.length) {
      widget.onTemperatureIncrease();
      setState(() => _stage = _FlashbackStage.success);
      _stageTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() => _stage = _FlashbackStage.carSmooth);
        _stageTimer = Timer(const Duration(milliseconds: 2500), () {
          if (!mounted) return;
          setState(() => _stage = _FlashbackStage.parkArrival);
          _stageTimer = Timer(const Duration(milliseconds: 2500), () {
            if (!mounted) return;
            setState(() => _stage = _FlashbackStage.parkKid);
            _stageTimer = Timer(const Duration(milliseconds: 1500), () {
              if (!mounted) return;
              // TODO: 앞치마 갈아입는 GIF 씬 연결 예정 (chaeon_apron_putting_on.gif / chaeon_apron_idle.gif)
              widget.onComplete();
            });
          });
        });
      });
    }
  }

  // 배경 이미지 경로를 현재 단계에 맞춰 반환
  String _backgroundAssetFor(_FlashbackStage stage) {
    switch (stage) {
      case _FlashbackStage.tutorial:
      case _FlashbackStage.carBumpyClouds:
      case _FlashbackStage.success:
        return 'assets/images/memory_car_bumpy.gif';
      case _FlashbackStage.carSmooth:
        return 'assets/images/memory_car_smooth.gif';
      case _FlashbackStage.parkArrival:
        return 'assets/images/memory_park_arrival.gif';
      case _FlashbackStage.parkKid:
        return 'assets/images/memory_park_kid.png';
    }
  }

  // 화면 크기에 맞춰 배경 이미지와 구름, 성공 메시지 등을 표시
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
                  ),
                ),
              ),
              if (_stage == _FlashbackStage.tutorial)
                // 4-1: 일회성 튜토리얼. 암전 + 구름 하나 하이라이트 + 드래그 방향 화살표.
                // 드래그로 해제되면 전환 애니메이션 없이 즉시 사라지고 실제 미니게임으로 넘어감
                Positioned.fill(
                  key: const ValueKey('cloud_tutorial'),
                  child: GestureDetector(
                    onPanStart: _onTutorialPanStart,
                    onPanUpdate: _onTutorialPanUpdate,
                    child: Builder(
                      builder: (context) {
                        // 하이라이트는 실제 미니게임 구름들과 같은 상단부(top: rH(40))에,
                        // 화면 가로 중앙에 오도록 배치. 화살표는 그 바로 왼쪽에 작게 붙임
                        final double hintSize = rW(240);
                        final double hintLeft = w / 2 - hintSize / 2;
                        final double hintTop = rH(40);
                        final double arrowWidth = rW(50);
                        final double trailWidth =
                            arrowWidth +
                            arrowWidth *
                                arrowTrailOverlap *
                                (arrowTrailCount - 1);
                        // 원 테두리 안쪽에 여백 없이 그림(구름)이 바로 시작하지 않으므로,
                        // 트레일 오른쪽 끝이 테두리를 살짝 넘어 구름 쪽으로 들어가게 겹쳐서
                        // 눈으로 봤을 때 완전히 붙어 보이도록 함
                        final double trailRight = hintLeft + rW(14);
                        final double trailLeft = trailRight - trailWidth;
                        final double trailTop =
                            hintTop + hintSize / 2 - arrowWidth / 2;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.55),
                              ),
                            ),
                            Positioned(
                              left: hintLeft,
                              top: hintTop,
                              child: Container(
                                width: hintSize,
                                height: hintSize,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(color: Colors.white, width: 4),
                                  ),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/cloud_tutorial_hint.png',
                                    width: rW(200),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: trailLeft,
                              top: trailTop,
                              child: _ArrowTrail(arrowWidth: arrowWidth),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              if (_stage == _FlashbackStage.carBumpyClouds)
                for (int i = 0; i < _cloudSpecs.length; i++)
                  _DraggableCloud(
                    key: ValueKey('cloud_$i'),
                    left: rW(_cloudSpecs[i].left),
                    top: rH(_cloudSpecs[i].top),
                    width: rW(_cloudSpecs[i].width),
                    height: rW(_cloudSpecs[i].width) / _cloudAspect,
                    onCleared: _onCloudCleared,
                  ),
              // SUCCESS 이미지: 화면 상단 20% 지점
              Positioned(
                left: 0,
                right: 0,
                top: rH(402 * 0.2),
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _stage == _FlashbackStage.success ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Image.asset(
                        'assets/images/minigame_success.png',
                        width: rW(280),
                        fit: BoxFit.contain,
                      ),
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

// 구름 하나: 짧은 거리만 드래그해도 축소 + 페이드아웃되며 사라짐
class _DraggableCloud extends StatefulWidget {
  const _DraggableCloud({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onCleared,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onCleared;

  @override
  State<_DraggableCloud> createState() => _DraggableCloudState();
}

class _DraggableCloudState extends State<_DraggableCloud> {
  // 드래그 시작 지점부터 누적된 이동 거리. 짧은 거리(_dragDismissThreshold)만 넘어도 바로 사라짐
  Offset _dragAccum = Offset.zero;
  bool _dismissed = false;

  void _onPanStart(DragStartDetails details) {
    _dragAccum = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dismissed) return;
    _dragAccum += details.delta;
    if (_dragAccum.distance >= _dragDismissThreshold) {
      setState(() => _dismissed = true);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) widget.onCleared();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.left,
      top: widget.top,
      width: widget.width,
      height: widget.height,
      child: IgnorePointer(
        ignoring: _dismissed,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          child: AnimatedScale(
            scale: _dismissed ? 0.4 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeIn,
            child: AnimatedOpacity(
              opacity: _dismissed ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: Image.asset(
                'assets/images/memory_cloud.png',
                width: widget.width,
                height: widget.height,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _ArrowTrail 크기 계산을 배치하는 쪽(트레일이 몇 개 겹치는지)과 트레일 위젯 내부가
// 항상 같은 값을 쓰도록 공유하는 상수
const int arrowTrailCount = 6;
const double arrowTrailOverlap = 0.4;

// 드래그 방향 힌트: cloud_drag_arrow.png 여러 장을 겹쳐 놓고, 오른쪽(구름과 맞닿는 쪽)은
// 선명하게 왼쪽으로 갈수록 투명해지는 그라데이션을 씌워 흘러나가는 트레일처럼 보이게 함.
// 트레일 전체가 살짝 좌우로 흔들리는 반복 애니메이션도 함께 재생
class _ArrowTrail extends StatefulWidget {
  const _ArrowTrail({
    required this.arrowWidth,
    this.arrowCount = arrowTrailCount,
  });

  final double arrowWidth;
  final int arrowCount;

  @override
  State<_ArrowTrail> createState() => _ArrowTrailState();
}

class _ArrowTrailState extends State<_ArrowTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftController;
  late final Animation<double> _driftX;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _driftX = Tween<double>(begin: 0, end: -widget.arrowWidth * 0.25).animate(
      CurvedAnimation(parent: _driftController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // cloud_drag_arrow.png가 겹치는 간격만큼씩 왼쪽으로 밀어서 배치
    final double step = widget.arrowWidth * arrowTrailOverlap;
    final double totalWidth =
        widget.arrowWidth + step * (widget.arrowCount - 1);

    final Widget trail = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [Colors.white, Colors.transparent],
      ).createShader(bounds),
      child: SizedBox(
        width: totalWidth,
        height: widget.arrowWidth,
        child: Stack(
          children: [
            for (int i = 0; i < widget.arrowCount; i++)
              Positioned(
                left: step * i,
                top: 0,
                child: Image.asset(
                  'assets/images/cloud_drag_arrow.png',
                  width: widget.arrowWidth,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _driftX,
      builder: (context, child) =>
          Transform.translate(offset: Offset(_driftX.value, 0), child: child),
      child: trail,
    );
  }
}
