// lib/features/chapter1/memory_flashback_scene.dart

import 'dart:async';
import 'package:flutter/material.dart';

enum _FlashbackStage {
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

// 구름 위치와 크기 사양. 화면 비율이 874x402 기준임
const List<_CloudSpec> _cloudSpecs = [
  _CloudSpec(left: 30, top: 30, width: 200),
  _CloudSpec(left: 250, top: 10, width: 160),
  _CloudSpec(left: 430, top: 40, width: 220),
  _CloudSpec(left: 660, top: 20, width: 150),
  _CloudSpec(left: 120, top: 190, width: 190),
  _CloudSpec(left: 420, top: 200, width: 210),
];

// memory_cloud.png 원본 비율(370x250)
const double _cloudAspect = 370 / 250;

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
  _FlashbackStage _stage = _FlashbackStage.carBumpyClouds;
  int _clearedCloudCount = 0;
  Timer? _stageTimer;
  bool _imagesPrecached = false;

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
              Positioned.fill(
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
  // 드래그 시작 지점부터 누적된 이동 거리. 짧은 거리(20px)만 넘어도 바로 사라짐
  static const double _dismissThreshold = 20.0;

  Offset _dragAccum = Offset.zero;
  bool _dismissed = false;

  void _onPanStart(DragStartDetails details) {
    _dragAccum = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dismissed) return;
    _dragAccum += details.delta;
    if (_dragAccum.distance >= _dismissThreshold) {
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
