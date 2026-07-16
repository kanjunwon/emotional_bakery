// lib/features/chapter1/components/interactive_zone.dart

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:emotional_bakery/core/models/interaction_model.dart';
import '../bakery_game.dart';

// JSON 좌표를 기반으로 화면에는 보이지 않는 투명한 클릭 히트박스를 생성하는 컴포넌트
class InteractiveZone extends PositionComponent
    with TapCallbacks, HasGameRef<BakeryGame> {
  final InteractionObject objectData;

  InteractiveZone({required this.objectData}) {
    // JSON에 적힌 좌표와 크기를 그대로 플레임 컴포넌트 수치로 매핑
    position = Vector2(objectData.clickX, objectData.clickY);
    size = Vector2(objectData.width, objectData.height);
  }

  // 손가락으로 누르면 등장하는 이벤트 처리
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    // 게임 진행 중이 아니라면 클릭 이벤트 무시
    if (!gameRef.canInteract) return;

    // JSON에 적힌 대사 배열을 하나의 문자열로 합쳐서 게임 화면에 전달
    gameRef.onInteract?.call(objectData.dialogue.join('\n'));
  }
}
