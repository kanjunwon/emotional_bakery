import 'package:flame/components.dart';
import 'dart:ui';

class Chaeon extends SpriteComponent with HasGameRef {
  double speed = 225; // 캐릭터 이동 속도 (튜토리얼과 동일하게 통일)
  int moveDirection = 0; // -1: 왼쪽, 0: 정지, 1: 오른쪽
  final double mapWidth; // 맵 전체 가로 길이 한계선

  Chaeon({required this.mapWidth});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // 채온 이미지 (실제 GIF는 game_play_screen 오버레이가 담당, 여기선 위치 앵커용 정적 이미지만 로드)
    sprite = await gameRef.loadSprite('chaeon_idle_right.gif');

    // 캐릭터 크기 설정
    size = Vector2(172, 172);

    // 캐릭터의 기준점 발바닥 중앙 잡기
    anchor = Anchor.bottomCenter;

    // 시작 위치
    position = Vector2(10, 350);
  }

  @override
  void render(Canvas canvas) {}

  @override
  void update(double dt) {
    super.update(dt);

    // 속도 * 방향 * 델타타임 = 프레임 독립적 이동
    position.x += moveDirection * speed * dt;

    // 왼쪽 끝, 오른쪽 끝 벽에 부딪히면 못 나가게 가두기
    position.x = position.x.clamp(size.x / 2, mapWidth - (size.x / 2));

    // 왼쪽 갈 때 이미지 뒤집고, 오른쪽 갈 때 원상복구
    if (moveDirection < 0 && !isFlippedHorizontally) {
      flipHorizontallyAroundCenter();
    } else if (moveDirection > 0 && isFlippedHorizontally) {
      flipHorizontallyAroundCenter();
    }
  }
}
