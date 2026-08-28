// lib/features/chapter4/chapter4_making_bread_cutscene_data.dart

// 챕터4 편지 컷씬(LetterScene) -> chapter4_after_letter.json 끝나고 재생되는 빵만들기
// 컷씬 대사+이미지 목록. dialogue_overlay.dart의 DialogueOverlay가 data 파라미터로
// 이걸 받아서 프롤로그(_prologueData)랑 동일한 방식으로 재생함
const List<Map<String, String>> chapter4MakingBreadCutsceneData = [
  {"text": "릴리안과 채온은 함께 슬픔의 빵을 만들었어요.", "image": "making_bread_bg_1.png"},
  {
    "text": "채온은 처음엔 만들기 싫어하는 눈치였지만, 이내 빵 만드는 것에 집중했어요.",
    "image": "making_bread_bg_2.png",
  },
];
