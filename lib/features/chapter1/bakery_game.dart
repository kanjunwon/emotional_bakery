// lib/features/chapter1/bakery_game.dart

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/experimental.dart';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/features/chapter1/chaeon.dart';
import 'package:emotional_bakery/features/chapter1/lillian.dart';

class BakeryGame extends FlameGame {
  late Chaeon chaeon;
  late Lillian lillian;
  final double mapWidth = 1852; // 배경 이미지 가로 길이

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 배경 레이어
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

  // 전역 대화창 제어 함수
  void showDialogue(List<String> textLines) {
    // 나중에 플레임 오버레이(DialogueOverlay)나 구현한 글로벌 대화창 위젯에 textLines(대사 리스트)를 꽂아주는 로직
    print("게임 엔진에서 대사 완료: ${textLines.first}");

    // ex) overlays.add('dialogue'); -> 오버레이 키는 플레임 내장 함수
  }
}
