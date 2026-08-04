// lib/core/services/chapter_progress.dart
//
// 챕터 해금 상태를 앱 전역에서 들고 있는 저장소. chapter_select_screen.dart의
// _isChapter1Unlocked처럼 화면 State에 두면 화면이 새로 생성될 때마다 리셋되는데,
// 여기는 static이라 앱이 켜져있는 동안은 값이 계속 유지됨

class ChapterProgress {
  static bool isChapter2Unlocked = false;
}
