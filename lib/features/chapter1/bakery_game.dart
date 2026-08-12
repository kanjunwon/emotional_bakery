// lib/features/chapter1/bakery_game.dart

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:emotional_bakery/features/chapter1/chaeon.dart';
import 'package:emotional_bakery/features/chapter1/components/interactive_zone.dart';
import 'package:emotional_bakery/core/services/interaction_loader.dart';

// 계단(주방 입구) 트리거 x좌표. game_play_screen.dart의 계단 하강 애니메이션 시작 좌표
// (_stairsTopPoint.dx)와 반드시 같은 값이어야 함. 다르면 트리거 시점의 실제 위치와
// 하강 애니메이션 시작 위치가 어긋나서, 채온이가 순간적으로 뒤로(왼쪽으로) 튕기는 것처럼 보임
const double kitchenStairsTriggerX = 1680;

class BakeryGame extends FlameGame {
  BakeryGame({this.skipChapter1Events = false}) {
    // 챕터3 빵집 재진입 모드: 가이드 대사(x=650)/릴리안 등장(x=1305) 트리거를 처음부터
    // "이미 발동됨" 상태로 시작해서 무효화하고, 계단 트리거만 살아있게 함
    if (skipChapter1Events) {
      _hasTriggeredGuide = true;
      _hasTriggeredPostSceneEnd = true;
      isKitchenApproachActive = true;
    }
  }

  // true면 챕터3에서 빵집에 다시 들어온 경우. 챕터1 최초 플레이 흐름과 구분하는 용도
  final bool skipChapter1Events;

  Chaeon? chaeon;
  final double mapWidth = 1852; // 배경 이미지 가로 길이
  final double mapHeight = 402; // 배경 이미지 세로 길이

  bool isMovementBlocked = false;
  bool canInteract = true;
  bool _hasTriggeredGuide = false;
  bool _hasTriggeredPostSceneEnd = false;
  bool _hasTriggeredStairs = false;
  // game_play_screen에서 DialoguePhase.kitchenApproach가 됐을 때만 true로 켜줌.
  // 이 플래그가 켜지기 전까진 계단 트리거 체크 자체를 안 해서, chaeon 위치가 이전 단계에서
  // 어쩌다 계단 트리거 좌표를 넘겨버려도 _hasTriggeredStairs가 미리 소모되지 않게 막는 안전장치
  bool isKitchenApproachActive = false;
  // 채온이가 막 mount된 첫 프레임인지 추적. 안 하면 가만히 서있는 상태로 시작할 때
  // onGameUpdate가 한 번도 안 불려서 플러터 쪽 위치가 초기값(0)에 멈춰 안 보이게 됨
  bool _wasChaeonMounted = false;

  double? lillianArrivalX;

  // 릴리안 등장 이후 카메라가 목표 지점으로 이동하는 속도
  final double _cameraPanSpeed = 1.8;

  // 대사 종료처럼 카메라 포커스가 갑자기 바뀔 때, 순간이동하지 않고 부드럽게
  // 따라잡도록 트리거. 다 따라잡으면 자동으로 즉시 추적 모드로 복귀함
  bool _isCameraCatchingUp = false;
  void startCameraCatchUp() {
    _isCameraCatchingUp = true;
  }

  // 플러터 UI 레이어와 연동하기 위한 콜백 함수 포인터들
  Function(List<String>)? onShowDialogue;
  Function()? onGameUpdate;
  Function()? onReachLeftEdge; // 왼쪽 끝에서 계속 왼쪽으로 이동 시 프롤로그로 전환
  Function(String)? onInteract; // 배경 오브젝트 클릭 시 팝업 표시
  Function()? onReachPostSceneEnd; // 첫 만남 대사 후 채온이가 1200 지점 도착 시
  Function()? onReachStairs; // 계단 근처 도달 시 (주방으로 내려가는 연출 트리거)

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

    // 배경 위 클릭 가능한 오브젝트 히트박스 배치
    final stageObjects = await InteractionLoader.loadStageObjects(
      'bakery_bg_main.png',
    );
    for (final objectData in stageObjects) {
      world.add(InteractiveZone(objectData: objectData));
    }

    /* // 사용 안함
    lillian = Lillian();
    lillian.position = Vector2(1200, 320);
    world.add(lillian);
    */

    // 채온 레이어
    chaeon = Chaeon(mapWidth: mapWidth);
    world.add(chaeon!);

    // 카메라 초기 위치를 맵 왼쪽 끝으로 설정
    camera.viewfinder.anchor = Anchor.centerLeft;
    camera.viewfinder.position = Vector2(0, mapHeight / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 카메라 줌을 맵 세로 길이에 맞춰서 화면에 꽉 차게 조정
    if (size.y > 0) {
      camera.viewfinder.zoom = size.y / mapHeight;
    }

    // 카메라가 채온이를 따라가도록 위치를 업데이트
    bool positionChangedThisFrame = false;

    if (chaeon != null && chaeon!.isMounted) {
      // 화면에 실제로 보이는 가로 폭
      double visibleWidth = size.x / camera.viewfinder.zoom;
      // 뷰포트가 맵보다 넓은 극단적인 비율이어도 clamp 범위가 뒤집히지 않도록 방어
      double maxLeftEdge = (mapWidth - visibleWidth).clamp(0.0, mapWidth);

      // 카메라가 따라갈 초점 좌표를 계산
      double focusX = lillianArrivalX != null
          ? (chaeon!.position.x + lillianArrivalX!) / 2
          : chaeon!.position.x;

      // 초점이 화면 중앙을 따라며, 카메라 범위 제한
      double targetLeftEdge = (focusX - visibleWidth / 2).clamp(
        0.0,
        maxLeftEdge,
      );

      double newLeftEdge;
      if (lillianArrivalX != null || _isCameraCatchingUp) {
        // 릴리안 등장 중이거나, 포커스가 갑자기 바뀌어 따라잡는 중이면 서서히 이동
        double currentLeftEdge = camera.viewfinder.position.x;
        double t = (_cameraPanSpeed * dt).clamp(0.0, 1.0);
        newLeftEdge = currentLeftEdge + (targetLeftEdge - currentLeftEdge) * t;
        // 카메라가 목표 지점에 도달하면, 추적 모드로 복귀
        if (_isCameraCatchingUp && (targetLeftEdge - newLeftEdge).abs() < 1.0) {
          _isCameraCatchingUp = false;
        }
      } else {
        // 평소 채온이 추적은 카메라 지연 없이 따라가기
        newLeftEdge = targetLeftEdge;
      }

      double previousLeftEdge = camera.viewfinder.position.x;

      // 카메라 위치 업데이트
      camera.viewfinder.position = Vector2(
        newLeftEdge,
        camera.viewfinder.position.y,
      );

      positionChangedThisFrame =
          !_wasChaeonMounted ||
          chaeon!.moveDirection != 0 ||
          (newLeftEdge - previousLeftEdge).abs() > 0.01;
      _wasChaeonMounted = true;
    } else {
      _wasChaeonMounted = false;
    }

    // 채온이가 계속 왼쪽으로 이동을 시도하면 프롤로그로 전환
    if (chaeon != null &&
        chaeon!.isMounted &&
        chaeon!.moveDirection < 0 &&
        chaeon!.position.x <= chaeon!.size.x / 2) {
      onReachLeftEdge?.call();
    }

    if (chaeon != null &&
        !_hasTriggeredGuide &&
        chaeon!.isMounted &&
        chaeon!.position.x >= 650) {
      _hasTriggeredGuide = true; // 스위치 ON

      // 대사 띄우는 중에는 조작 잠금
      isMovementBlocked = true;
      movePlayer(0);

      showDialogue([
        "지금부터 감정의 온도를 확인할 수 있습니다.\n당신의 선택에 따라 감정의 온도는 오를수도, 내려갈 수도 있습니다.",
        "뒤로가기 버튼을 통해 대화를 뒤로 돌릴 수 있습니다.\n단, 당신의 선택은 돌릴 수 없습니다.",
      ]);

      print("x=650 지점 도달");
    }

    // 첫 만남 대사 이후 다시 걸을 수 있게 된 구간에서, 채온이가 1200 지점에 도착하면
    // 방향키를 다시 숨기고 조작을 잠금 (나중에 해야함)
    if (chaeon != null &&
        !_hasTriggeredPostSceneEnd &&
        chaeon!.isMounted &&
        chaeon!.position.x >= 1305) {
      _hasTriggeredPostSceneEnd = true;
      isMovementBlocked = true;
      movePlayer(0);
      onReachPostSceneEnd?.call();
      print("x=1300 지점 도달");
      // 디버그: 이 시점 chaeon 실제 x랑 계단 트리거까지 남은 거리 확인용
      print(
        "postSceneEnd 도달 시 chaeon.x=${chaeon!.position.x}, "
        "계단 트리거(kitchenStairsTriggerX=$kitchenStairsTriggerX)까지 남은 거리="
        "${kitchenStairsTriggerX - chaeon!.position.x}",
      );
    }

    // 앞치마 갈아입고 다시 걸을 수 있게 된 구간에서, 채온이가 계단 근처에 도착하면
    // 조작을 잠금. 실제로 주방 전환까지 이어질지는 game_play_screen에서 대사 단계 보고 판단함.
    // isKitchenApproachActive가 켜지기 전까진 이 체크 자체를 안 하게 막아서, chaeon 위치가
    // 어쩌다 이전 단계에서 이 좌표를 넘겨버려도 _hasTriggeredStairs가 미리 소모되지 않게 함
    if (isKitchenApproachActive &&
        chaeon != null &&
        !_hasTriggeredStairs &&
        chaeon!.isMounted &&
        chaeon!.position.x >= kitchenStairsTriggerX) {
      _hasTriggeredStairs = true;
      isMovementBlocked = true;
      movePlayer(0);
      onReachStairs?.call();
      // 디버그: 계단 트리거가 실제로 발동한 시점의 chaeon x좌표 확인용
      print(
        "계단 트리거 발동: chaeon.x=${chaeon!.position.x}, "
        "kitchenStairsTriggerX=$kitchenStairsTriggerX",
      );
    }

    if (positionChangedThisFrame) {
      onGameUpdate?.call();
    }
  }

  // 외부 위젯에서 플레이어 방향 제어용 함수
  void movePlayer(int direction) {
    // 디버그: 방향키 없이 자동으로 걷는 버그 추적용. 호출될 때마다 direction이랑 호출 스택을 같이 찍음
    print('movePlayer($direction) 호출됨\n${StackTrace.current}');
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

  // 주방에서 다시 계단을 올라와 빵집으로 돌아왔을 때, 계단 트리거를 다시 쓸 수 있게 리셋
  void resetStairsTrigger() {
    _hasTriggeredStairs = false;
  }
}
