// lib/features/chapter4/chapter4_bad_ending_data.dart

// 챕터4 배드엔딩 컷씬 대사+이미지 목록. chapter4_after_past.json의 choice_001에서
// "아뇨... 싫어요."(line_015b1)를 고른 경우에만 재생됨. dialogue_overlay.dart의
// DialogueOverlay가 data 파라미터로 이걸 받아서 chapter4CutsceneData랑 동일한 방식으로 재생함
const List<Map<String, String>> chapter4BadEndingData = [
  {
    "text": "채온은 슬픔과 같은 아픈 감정을 마주하는 것은 거부하기로 했어요.",
    "image": "past_1.png",
  },
  {
    "text": "그리고 빵집에서 만들어주는 '행복의 빵'이 주는 달콤함에 중독되었어요.",
    "image": "endig_bad_2.png",
  },
  {
    "text": "결국 채온은 엄마를 향해 웃어주겠다는 목적은 잊어버리고 말았어요.",
    "image": "endig_bad_3.png",
  },
  {"text": "단지 매일매일 가짜 행복에 취해있을 뿐이었죠.", "image": "endig_bad_4.png"},
  {"text": "그러던 어느 날, 빵집이 사라지고 말았어요.", "image": "endig_bad_5.png"},
  {
    "text": "채온은 길거리를 돌아다니며 빵집을 찾아 하염없이 방황하기 시작했어요.",
    "image": "endig_bad_6.png",
  },
  {"text": "지금도, 어디선가 빵집을 찾아 헤매고 있을지도 몰라요.", "image": "endig_bad_7.png"},
];
