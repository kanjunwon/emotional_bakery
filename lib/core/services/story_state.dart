// lib/core/services/story_state.dart
//
// 선택지 고를 때 저장되는 재료 변수들을 앱 전역에서 들고 있는 저장소.
// chapter_progress.dart랑 같은 패턴으로 static 클래스로 구현해서, 화면이 새로
// 생성돼도 값이 리셋 안 되고 앱이 켜져있는 동안 계속 유지됨

class StoryState {
  static Map<String, dynamic> vars = {};
}
