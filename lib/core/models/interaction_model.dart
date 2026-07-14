// lib/core/models/interaction_model.dart
// JSON 읽어오는 모델 정의

class InteractionObject {
  final String id;
  final String name;
  final double clickX;
  final double clickY;
  final double width;
  final double height;
  final List<String> dialogue;

  InteractionObject({
    required this.id,
    required this.name,
    required this.clickX,
    required this.clickY,
    required this.width,
    required this.height,
    required this.dialogue,
  });

  // JSON 데이터를 Dart 객체로 변환하는 팩토리 생성자
  factory InteractionObject.fromJson(Map<String, dynamic> json) {
    return InteractionObject(
      id: json['id'] as String,
      name: json['name'] as String,
      clickX: (json['clickX'] as num).toDouble(),
      clickY: (json['clickY'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      dialogue: List<String>.from(json['dialogue'] as List),
    );
  }
}
