import 'package:flame/components.dart';

class Lillian extends SpriteComponent with HasGameRef {
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // 릴리안 도트 이미지 로드 (파일명은 에셋에 맞게 수정)
    sprite = await gameRef.loadSprite('lillian_normal.png');

    // 이미지 비율에 맞춰 크기 설정
    size = Vector2(80, 120);

    // 기준점을 발바닥 중앙으로 설정
    anchor = Anchor.bottomCenter;
  }
}
