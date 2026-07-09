// lib/features/chapter1/bakery_game.dart

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/experimental.dart';
import 'package:flutter/material.dart';
import '../../features/chapter1/chaeon.dart';
import '../../features/chapter1/lillian.dart';

class BakeryGame extends FlameGame {
  late Chaeon chaeon;
  late Lillian lillian;
  final double mapWidth = 2200.0; // 배경 이미지 가로 길이

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 배경 레이어
    // [AI 팁]: 튜토리얼 빵집 문을 열고 들어오면 로드될 대망의 챕터 1 메인 빵집 내부 배경 에셋!
    final bgSprite = await loadSprite('bakery_bg_main.png');
    final background = SpriteComponent(
      sprite: bgSprite,
      size: Vector2(mapWidth, size.y),
    );
    add(background);

    // 릴리안 레이어 (플레이어보다 뒤에 그리도록 먼저 추가)
    lillian = Lillian();
    // 맵 내부에서 NPC가 서 있을 좌표 설정 (x축 1200 지점)
    lillian.position = Vector2(1200, 320);
    add(lillian);

    // 채온 레이어
    chaeon = Chaeon(mapWidth: mapWidth);
    add(chaeon);

    // 카메라 추적 설정
    camera.follow(chaeon);

    // 카메라 이동 한계선 설정
    camera.setBounds(Rectangle.fromLTWH(0, 0, mapWidth, size.y));
  }

  // 외부 위젯에서 플레이어 방향 제어용 함수
  void movePlayer(int direction) {
    chaeon.moveDirection = direction;
  }
}
