// lib/core/services/story_state.dart
//
// 선택지 고를 때 저장되는 재료 변수들을 앱 전역에서 들고 있는 저장소.
// chapter_progress.dart랑 같은 패턴으로 static 클래스로 구현해서, 화면이 새로
// 생성돼도 값이 리셋 안 되고 앱이 켜져있는 동안 계속 유지됨

class StoryState {
  static Map<String, dynamic> vars = {};

  // chapter2_ingredient_quiz.json의 q1(eat/sleep/play) + q2(game/movie/exercise) +
  // q3(red/yellow/blue) 답변 조합으로 정해지는 마법 재료 이름.
  // line_ingredient_reveal의 {{ingredient}} 자리에 들어감
  static const Map<String, String> _ingredientByAnswer = {
    'eat_game_red': '붉은 태양의 결정',
    'eat_game_yellow': '노란 태양의 결정',
    'eat_game_blue': '푸른 태양의 결정',
    'eat_movie_red': '붉은 태양의 눈물',
    'eat_movie_yellow': '노란 태양의 눈물',
    'eat_movie_blue': '푸른 태양의 눈물',
    'eat_exercise_red': '붉은 태양의 가루',
    'eat_exercise_yellow': '노란 태양의 가루',
    'eat_exercise_blue': '푸른 태양의 가루',

    'sleep_game_red': '붉은 별의 결정',
    'sleep_game_yellow': '노란 별의 결정',
    'sleep_game_blue': '푸른 별의 결정',
    'sleep_movie_red': '붉은 별의 눈물',
    'sleep_movie_yellow': '노란 별의 눈물',
    'sleep_movie_blue': '푸른 별의 눈물',
    'sleep_exercise_red': '붉은 별의 가루',
    'sleep_exercise_yellow': '노란 별의 가루',
    'sleep_exercise_blue': '푸른 별의 가루',

    'play_game_red': '붉은 고래의 결정',
    'play_game_yellow': '노란 고래의 결정',
    'play_game_blue': '푸른 고래의 결정',
    'play_movie_red': '붉은 고래의 눈물',
    'play_movie_yellow': '노란 고래의 눈물',
    'play_movie_blue': '푸른 고래의 눈물',
    'play_exercise_red': '붉은 고래의 가루',
    'play_exercise_yellow': '노란 고래의 가루',
    'play_exercise_blue': '푸른 고래의 가루',
  };

  // q1/q2/q3 답변이 다 모였으면 그 조합에 해당하는 재료 이름을 반환, 아니면 null
  static String? resolveIngredientName() {
    final q1 = vars['q1'];
    final q2 = vars['q2'];
    final q3 = vars['q3'];
    if (q1 == null || q2 == null || q3 == null) return null;
    return _ingredientByAnswer['${q1}_${q2}_$q3'];
  }

  // 재료 이름과 같은 q1/q2/q3 조합으로 정해지는 재료 이미지 경로.
  // 재료 획득 팝업에서 보여줄 이미지를 찾을 때 씀
  static const Map<String, String> _ingredientImageByAnswer = {
    'eat_game_red': 'assets/images/ingredient_red_crystal.png',
    'eat_game_yellow': 'assets/images/ingredient_yellow_crystal.png',
    'eat_game_blue': 'assets/images/ingredient_blue_crystal.png',
    'eat_movie_red': 'assets/images/ingredient_red_tear.png',
    'eat_movie_yellow': 'assets/images/ingredient_yellopw_tear.png',
    'eat_movie_blue': 'assets/images/ingredient_blue_tear.png',
    'eat_exercise_red': 'assets/images/ingredient_red_powder.png',
    'eat_exercise_yellow': 'assets/images/ingredient_yellow_powder.png',
    'eat_exercise_blue': 'assets/images/ingredient_blue_powder.png',

    'sleep_game_red': 'assets/images/ingredient_red_crystal.png',
    'sleep_game_yellow': 'assets/images/ingredient_yellow_crystal.png',
    'sleep_game_blue': 'assets/images/ingredient_blue_crystal.png',
    'sleep_movie_red': 'assets/images/ingredient_red_tear.png',
    'sleep_movie_yellow': 'assets/images/ingredient_yellopw_tear.png',
    'sleep_movie_blue': 'assets/images/ingredient_blue_tear.png',
    'sleep_exercise_red': 'assets/images/ingredient_red_powder.png',
    'sleep_exercise_yellow': 'assets/images/ingredient_yellow_powder.png',
    'sleep_exercise_blue': 'assets/images/ingredient_blue_powder.png',

    'play_game_red': 'assets/images/ingredient_red_crystal.png',
    'play_game_yellow': 'assets/images/ingredient_yellow_crystal.png',
    'play_game_blue': 'assets/images/ingredient_blue_crystal.png',
    'play_movie_red': 'assets/images/ingredient_red_tear.png',
    'play_movie_yellow': 'assets/images/ingredient_yellopw_tear.png',
    'play_movie_blue': 'assets/images/ingredient_blue_tear.png',
    'play_exercise_red': 'assets/images/ingredient_red_powder.png',
    'play_exercise_yellow': 'assets/images/ingredient_yellow_powder.png',
    'play_exercise_blue': 'assets/images/ingredient_blue_powder.png',
  };

  // q1/q2/q3 답변이 다 모였으면 그 조합에 해당하는 재료 이미지 경로를 반환, 아니면 null
  static String? resolveIngredientImage() {
    final q1 = vars['q1'];
    final q2 = vars['q2'];
    final q3 = vars['q3'];
    if (q1 == null || q2 == null || q3 == null) return null;
    return _ingredientImageByAnswer['${q1}_${q2}_$q3'];
  }
}
