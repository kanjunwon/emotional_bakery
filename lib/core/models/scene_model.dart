// lib/core/models/scene_model.dart

class Scene {
  final String id;
  final String text;
  final String background;
  final String character;
  final String? nextId; // 다음 장면 ID (없을 수도 있음)
  final List<Choice>? choices; // 선택지 리스트 (없을 수도 있음)

  Scene({
    required this.id,
    required this.text,
    required this.background,
    required this.character,
    this.nextId,
    this.choices,
  });

  // JSON 데이터를 객체로 변환하는 팩토리 메서드
  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'],
      text: json['text'],
      background: json['background'],
      character: json['character'],
      nextId: json['next_id'],
      choices: json['choices'] != null
          ? (json['choices'] as List).map((i) => Choice.fromJson(i)).toList()
          : null,
    );
  }
}

class Choice {
  final String text;
  final String nextId;
  final int emotionDelta; // 감정 변화 수치

  Choice({
    required this.text,
    required this.nextId,
    required this.emotionDelta,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      text: json['text'],
      nextId: json['next_id'],
      emotionDelta: json['emotion_delta'] ?? 0,
    );
  }
}
