// lib/core/services/chapter_progress.dart
//
// 챕터 해금 상태를 앱 전역에서 들고 있는 저장소. chapter_select_screen.dart의
// _isChapter1Unlocked처럼 화면 State에 두면 화면이 새로 생성될 때마다 리셋되는데,
// 여기는 static이라 앱이 켜져있는 동안은 값이 계속 유지됨

class ChapterProgress {
  static bool isChapter2Unlocked = false;
  // 챕터2 완전 종료(chapter2_after_second_game.json까지 다 봄)하면 켜짐
  static bool isChapter3Unlocked = false;
  // 챕터3 완전 종료(일기장 퍼즐 시퀀스 끝, chapter3_after_eat.json까지 다 봄)하면 켜짐
  static bool isChapter4Unlocked = false;
  // 챕터4 온도 8~10(챕터5행) 엔딩 컷씬(chapter4_back_to_bakery_data)이 끝나면 켜짐
  static bool isChapter5Unlocked = false;
}
