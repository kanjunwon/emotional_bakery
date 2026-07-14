// lib/features/chapter1/bakery_game.dart

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:emotional_bakery/features/chapter1/chaeon.dart';

class BakeryGame extends FlameGame {
  Chaeon? chaeon;
  final double mapWidth = 1852; // 배경 이미지 가로 길이
  final double mapHeight = 402; // 배경 이미지 세로 길이

  // 가상 패드가 플레이어 이동을 막게 제어할 수 있는 상태 변수
  bool isMovementBlocked = false;

  // 가이드 박스가 딱 한 번만 켜지도록 제어하는 트리거 스위치
  bool _hasTriggeredGuide = false;

  // 플러터 UI 레이어와 연동하기 위한 콜백 함수 포인터들
  Function(List<String>)? onShowDialogue;
  Function()? onGameUpdate;

  // 게임 내부 좌표계(카메라)를 874x402로 고정
  BakeryGame()
    : super(
        camera: CameraComponent.withFixedResolution(width: 874, height: 402),
      );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 배경 레이어
    final bgSprite = await loadSprite('bakery_bg_main.png');
    final background = SpriteComponent(
      sprite: bgSprite,
      size: Vector2(mapWidth, mapHeight),
    );
    world.add(background);

    /*
    lillian = Lillian();
    lillian.position = Vector2(1200, 320);
    world.add(lillian);
    */

    // 채온 레이어
    chaeon = Chaeon(mapWidth: mapWidth);
    world.add(chaeon!);

    // 카메라 추적 설정
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(
      437,
      mapHeight / 2,
    ); // 시작 위치 (화면 절반너비, 세로 정중앙)
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (chaeon != null && chaeon!.isMounted) {
      double halfViewWidth = 874 / 2; // 카메라 고정 해상도(874)의 절반
      camera.viewfinder.position.x = chaeon!.position.x.clamp(
        halfViewWidth,
        mapWidth - halfViewWidth,
      );
    }

    if (chaeon != null &&
        !_hasTriggeredGuide &&
        chaeon!.isMounted &&
        chaeon!.position.x >= mapWidth * 0.3) {
      _hasTriggeredGuide = true; // 스위치 ON

      // 대사 띄우는 중에는 조작 완전히 잠금!
      isMovementBlocked = true;
      movePlayer(0);

      // 대화 트리거 실행!
      showDialogue([
        "지금부터 감정의 온도를 확인할 수 있습니다.\n당신의 선택에 따라 감정의 온도는 오를수도, 내려갈 수도 있습니다.",
        "뒤로가기 버튼을 통해 대화를 뒤로 돌릴 수 있습니다.\n단, 당신의 선택은 돌릴 수 없습니다.",
      ]);

      print("30% 지점 도달");
    }

    onGameUpdate?.call();
  }

  // 외부 위젯에서 플레이어 방향 제어용 함수
  void movePlayer(int direction) {
    if (isMovementBlocked) {
      chaeon?.moveDirection = 0;
      return;
    }
    chaeon?.moveDirection = direction;
  }

  // 전역 대화창 제어 함수
  void showDialogue(List<String> textLines) {
    onShowDialogue?.call(textLines);
  }
}
