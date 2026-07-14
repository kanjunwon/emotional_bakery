import 'package:flame/components.dart';

class Chaeon extends SpriteComponent with HasGameRef {
  double speed = 250.0; // 캐릭터 이동 속도
  int moveDirection = 0; // -1: 왼쪽, 0: 정지, 1: 오른쪽
  final double mapWidth; // 맵 전체 가로 길이 한계선

  Chaeon({required this.mapWidth});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // 채온 이미지
    sprite = await gameRef.loadSprite('chaeon_normal.png');

    // 스크린샷 비율 보고 대충 크기 맞춤 (피그마 크기 확인 필요)
    size = Vector2(70, 110);

    // 캐릭터의 기준점 발바닥 중앙 잡기
    anchor = Anchor.bottomCenter;

    // 시작 위치 (바닥 쯤)
    position = Vector2(100, (320 / 402) * gameRef.size.y); // 화면 비율에 맞춰 Y 좌표 조정
  }

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
