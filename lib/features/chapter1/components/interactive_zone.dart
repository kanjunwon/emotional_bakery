// lib/features/chapter1/components/interactive_zone.dart

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:emotional_bakery/core/models/interaction_model.dart';
import '../bakery_game.dart';

// JSON 좌표를 기반으로 화면에 보이지 않는 투명한 클릭 히트박스를 생성하는 컴포넌트
class InteractiveZone extends PositionComponent
    with TapCallbacks, HasGameRef<BakeryGame> {
  final InteractionObject objectData;

  InteractiveZone({required this.objectData}) {
    // JSON에 적힌 좌표와 크기를 그대로 플레임 컴포넌트 수치로 매핑
    position = Vector2(objectData.clickX, objectData.clickY);
    size = Vector2(objectData.width, objectData.height);
  }

  // 가판대든 메뉴판이든 손가락으로 누르는 순간 즉시 발동
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    // 플레이어가 멀리 있든 말든 즉시 대화 오버레이 켜고 대사 주입
    gameRef.showDialogue(objectData.dialogue);
    print("${objectData.name} 즉시 터치 완료");
  }
}
