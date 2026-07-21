// lib/features/chapter1/apron_change_scene.dart
//
// first_bread.json 종료 후 재생되는 앞치마 갈아입기 컷씬.
// chaeon_apron_putting_on.gif(갈아입는 동작) → chaeon_apron_idle.gif(완료, 정지 상태)로
// 전환 후 잠깐 보여주고 종료. memory_flashback_scene.dart의 상태 전이 패턴을 재사용.

import 'dart:async';
import 'package:flutter/material.dart';

enum _ApronStage { puttingOn, idle }

class ApronChangeScene extends StatefulWidget {
  const ApronChangeScene({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<ApronChangeScene> createState() => _ApronChangeSceneState();
}

class _ApronChangeSceneState extends State<ApronChangeScene> {
  _ApronStage _stage = _ApronStage.puttingOn;
  Timer? _stageTimer;
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    // 갈아입는 동작을 재생한 뒤 idle로 전환
    _stageTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      debugPrint('앞치마 갈아입기: puttingOn -> idle 전환');
      setState(() => _stage = _ApronStage.idle);
      // idle 상태를 잠깐 보여준 뒤 씬 종료
      _stageTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        debugPrint('앞치마 갈아입기: idle 표시 종료, onComplete 호출');
        widget.onComplete();
      });
    });
  }

  // 이미지 프리캐싱: 첫 빌드 시점에 한 번만 실행
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/chaeon_apron_putting_on.gif',
        'assets/images/chaeon_apron_idle.gif',
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

  // 단계별 GIF 경로 반환
  String _assetFor(_ApronStage stage) {
    switch (stage) {
      case _ApronStage.puttingOn:
        return 'assets/images/chaeon_apron_putting_on.gif';
      case _ApronStage.idle:
        return 'assets/images/chaeon_apron_idle.gif';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String asset = _assetFor(_stage);
    return Container(
      color: Colors.black,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Image.asset(
          asset,
          key: ValueKey(asset),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
