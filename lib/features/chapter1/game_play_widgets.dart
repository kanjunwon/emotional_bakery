// lib/features/chapter1/game_play_widgets.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';

// table.json a분기(먹는 대사, 온도 -1 구간)에서 전체화면 클로즈업으로 보여줄 노드.
// line_004a1(대사 끝)~line_004a2(다음 대사 시작) 사이에 넣은 빈 대사 노드 동안만 보여줌
const List<String> eatingCloseupNodeIdsA = ['line_004a1_eat'];
// table.json b분기(먹는 대사, 온도 +1 구간)에서 전체화면 클로즈업으로 보여줄 노드.
// line_004b2(대사 끝)~line_004b3(다음 대사 시작) 사이에 넣은 빈 대사 노드 동안만 보여줌
const List<String> eatingCloseupNodeIdsB = ['line_004b_eat'];

// 채온이 빵 먹는 장면에서 전체화면 클로즈업으로 보여주는 이미지. 분기와 상관없이 항상 동일한 2프레임 번갈이
const List<String> eatingCloseupFrames = [
  'assets/images/chaeon_eating_1.png',
  'assets/images/chaeon_eating_2.png',
];

// chaeonSpriteOverrides 항목 하나. beforeReveal은 말풍선 뜨기 전(GIF 재생 중)에 보여줄 에셋이고,
// afterReveal은 말풍선이 뜬 순간부터 바꿔줄 에셋. afterReveal이 없으면 그 시점부턴 기본 idle로 폴백.
// verticalOffsetPx는 그 에셋이 기본 idle 이미지 대비 세로로 어긋나 보일 때 보정하는 값(위로 보정하려면 음수)
class ChaeonSpriteOverride {
  const ChaeonSpriteOverride({
    required this.beforeReveal,
    this.beforeRevealVerticalOffsetPx = 0,
    this.afterReveal,
    this.afterRevealVerticalOffsetPx = 0,
  });

  final String beforeReveal;
  final double beforeRevealVerticalOffsetPx;
  final String? afterReveal;
  final double afterRevealVerticalOffsetPx;
}

// first_bread.json 특정 노드에 머무는 동안만 채온이 스프라이트를 잠깐 바꿔주는 매핑.
// 여기 없는 노드거나 first_bread.json 단계가 아니면 기존 idle/holding_bread 로직을 그대로 씀.
// 주의: table.json도 line_001/line_002 같은 같은 이름의 노드 ID를 쓰므로, 이 맵은 반드시
// DialoguePhase.firstBread일 때만 참조해야 함 (game_play_screen.dart 쪽에서 처리)
const Map<String, ChaeonSpriteOverride> chaeonSpriteOverrides = {
  'line_001': ChaeonSpriteOverride(
    beforeReveal: 'assets/images/chaeon_emotion_0to100.gif',
    beforeRevealVerticalOffsetPx: -12,
    afterReveal: 'assets/images/chaeon_emotion_reveal.gif',
    afterRevealVerticalOffsetPx: -12,
  ),
  'line_002': ChaeonSpriteOverride(
    beforeReveal: 'assets/images/chaeon_emotion_100to0.gif',
    beforeRevealVerticalOffsetPx: -12,
  ),
};

// first_meet.json 특정 노드에 머무는 동안만 릴리안 스프라이트를 잠깐 바꿔주는 매핑.
// eat/cry 노드는 대사 없이 GIF만 한 번 재생되고 끝나면 자동으로 다음 노드로 넘어가고,
// a7/a8 노드는 crying 정지 이미지를 대사가 있는 동안 계속 보여줌.
// 여기 없는 노드거나 first_meet.json 단계가 아니면 기존 idle/walk 로직을 그대로 씀
const Map<String, String> lillianSpriteOverrides = {
  'line_029a6_eat': 'assets/images/lillian_eating_bread.gif',
  'line_029a6_cry': 'assets/images/lillian_crying.gif',
  'line_029a7': 'assets/images/lillian_crying.png',
  'line_029a8': 'assets/images/lillian_crying.png',
};

class EatingCloseupOverlay extends StatefulWidget {
  const EatingCloseupOverlay({super.key, this.onFinished});

  // eating_1 -> eating_2 순서로 한 번씩 보여준 뒤 호출되는 콜백 (다음 대사로 자동 진행용)
  final VoidCallback? onFinished;

  @override
  State<EatingCloseupOverlay> createState() => _EatingCloseupOverlayState();
}

class _EatingCloseupOverlayState extends State<EatingCloseupOverlay> {
  static const Duration _frame1HoldDuration = Duration(milliseconds: 500);
  static const Duration _crossfadeDuration = Duration(milliseconds: 600);
  static const Duration _frame2HoldDuration = Duration(milliseconds: 500);

  int _frameIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // eating_1을 500ms 그대로 보여준 뒤 eating_2로 전환 시작
    _timer = Timer(_frame1HoldDuration, () {
      if (!mounted) return;
      setState(() => _frameIndex = 1);
      // 크로스페이드(600ms) + eating_2 유지(500ms) 후 완료 콜백 호출
      _timer = Timer(_crossfadeDuration + _frame2HoldDuration, () {
        widget.onFinished?.call();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      // 화면을 꽉 채우도록 BoxFit.cover 적용
      child: AnimatedSwitcher(
        duration: _crossfadeDuration,
        child: Image.asset(
          eatingCloseupFrames[_frameIndex],
          key: ValueKey(eatingCloseupFrames[_frameIndex]),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

// main_dialogue_box_1~9.png의 원본 가로 크기(px). 전부 높이는 60으로 고정.
const List<double> dialogueBoxWidths = [
  107,
  147,
  188,
  232,
  274,
  317,
  361,
  404,
  451,
];

Widget buildInteractionBox({
  required String text,
  required double Function(double) rW,
  required double Function(double) rH,
}) {
  return CenteredDialogueBox(
    key: const ValueKey('interaction_box'),
    textWidget: Text(
      text,
      textAlign: TextAlign.center,
      style: dialogueTextStyle(rW),
    ),
    rW: rW,
    rH: rH,
  );
}

// 온도계 위젯 (암전 레이어 위/아래 두 슬롯에서 재사용)
Widget buildThermometer({
  required String key,
  required double Function(double) rW,
  required double Function(double) rH,
  required int temperature,
  required String? temperatureChangeText,
}) {
  return Positioned(
    key: ValueKey(key),
    left: rW(7),
    top: rH(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/main_thermometer_$temperature.png',
          gaplessPlayback: true,
          width: rW(422),
          fit: BoxFit.contain,
        ),
        if (temperatureChangeText != null) ...[
          SizedBox(height: rH(5)),
          Padding(
            padding: EdgeInsets.only(left: rW(77)),
            child: buildBlackRoundedBadge(
              temperatureChangeText,
              rW: rW,
              rH: rH,
            ),
          ),
        ],
      ],
    ),
  );
}

// 검은 반투명 배경에 둥근 모서리 흰 글씨 안내 배지. 선택지 되돌리기 불가 안내용으로만 쓰임
Widget buildBlackRoundedBadge(
  String text, {
  required double Function(double) rW,
  required double Function(double) rH,
}) {
  return Container(
    width: rW(210),
    height: rH(30),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.5),
      borderRadius: BorderRadius.circular(rW(26)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: rW(12),
        fontWeight: FontWeight.w300,
        fontFamily: 'SCDream',
      ),
    ),
  );
}

// 뒤로가기 버튼
Widget buildBackButton({
  required String key,
  required double Function(double) rW,
  required double Function(double) rH,
  required VoidCallback onTap,
}) {
  return Positioned(
    key: ValueKey(key),
    left: rW(714),
    top: rH(15),
    child: GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/main_back_btn.png',
        width: rW(54),
        height: rH(54),
        fit: BoxFit.contain,
      ),
    ),
  );
}

// 설정(메뉴) 버튼
Widget buildSettingButton({
  required String key,
  required double Function(double) rW,
  required double Function(double) rH,
  required VoidCallback onTap,
}) {
  return Positioned(
    key: ValueKey(key),
    left: rW(788), // 뒤로가기 버튼(714) + 너비(54) + 간격(20)
    top: rH(15),
    child: GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/main_setting_btn.png',
        width: rW(54),
        height: rH(54),
        fit: BoxFit.contain,
      ),
    ),
  );
}

// 커스텀 대사창 레이아웃 빌더
Widget buildCustomDialogue({
  required String key,
  required int step,
  required double Function(double) rW,
  required double Function(double) rH,
}) {
  List<TextSpan> spans = [];
  if (step == 0) {
    spans = [
      const TextSpan(text: "지금부터 감정의 온도를 확인할 수 있습니다.\n"),
      const TextSpan(
        text: "당신의 선택에 따라 ",
        style: TextStyle(color: Color(0xFFFF7100), fontWeight: FontWeight.w600),
      ),
      const TextSpan(text: "감정의 온도는 오를수도, 내려갈 수도 있습니다."),
    ];
  } else {
    spans = [
      const TextSpan(text: "뒤로가기 버튼을 통해 대화를 뒤로 돌릴 수 있습니다.\n단, 당신의 "),
      const TextSpan(
        text: "선택은 돌릴 수 없습니다.",
        style: TextStyle(color: Color(0xFFFF7100), fontWeight: FontWeight.w600),
      ),
    ];
  }

  return Positioned(
    key: ValueKey(key),
    left: step == 0 ? rW(26) : null,
    right: step == 0 ? null : rW(32),
    top: rH(75),
    child: DialogueBoxFrame(
      textWidget: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(style: dialogueTextStyle(rW), children: spans),
      ),
      rW: rW,
      rH: rH,
    ),
  );
}

// 채온-릴리안 말풍선. 대사 길이에 맞는 가장 작은 이미지 골라서 top 100, 말하는 캐릭터 중심에 표시. 채온이면 좌우 반전.
Widget buildSceneBubble({
  required DialogueNode node,
  required double Function(double) rW,
  required double Function(double) rH,
  required double chaeonCenterX,
  required double lillianCenterX,
  required int typedCharCount,
  int? charCount,
}) {
  final bool isChaeon = node.speaker == 'chaeon';
  final double centerX = isChaeon ? chaeonCenterX : lillianCenterX;
  final bool isLargeText = node.spans.any((s) => s.size == 18);

  final TextStyle baseStyle = TextStyle(
    color: const Color(0xFF5A3E2B),
    fontSize: rW(13),
    height: 1.1,
    fontWeight: FontWeight.w500,
    fontFamily: 'SCDream',
  );

  InlineSpan spanToInline(DialogueSpan s) => TextSpan(
    text: s.text,
    style: baseStyle.copyWith(
      color: s.color ?? baseStyle.color,
      fontWeight: s.bold ? FontWeight.w700 : baseStyle.fontWeight,
      fontSize: s.size != null ? rW(s.size!) : baseStyle.fontSize,
    ),
  );

  // 말풍선 크기는 전체 대사 기준으로 고정
  final List<InlineSpan> fullSpans = node.spans.map(spanToInline).toList();
  final TextPainter tp = TextPainter(
    text: TextSpan(children: fullSpans),
    textDirection: TextDirection.ltr,
  )..layout();

  // 실제로 그리는 텍스트는 타이핑 진행도만큼만 잘라서 표시
  final List<InlineSpan> visibleSpans = SceneDialogueController.truncateSpans(
    node.spans,
    charCount ?? typedCharCount,
  ).map(spanToInline).toList();

  // 여백 뺀 안쪽 공간에 텍스트 들어가는 가장 작은 말풍선 선택, 안 들어가면 제일 큰 걸로
  const double nativeHorizontalPadding = 24;
  int boxIndex = dialogueBoxWidths.length;
  for (int i = 0; i < dialogueBoxWidths.length; i++) {
    double boxWidthPx = rW(dialogueBoxWidths[i]);
    double availableWidth = boxWidthPx - rW(nativeHorizontalPadding * 2);
    if (tp.width <= availableWidth) {
      boxIndex = i + 1;
      break;
    }
  }

  final double bubbleWidth = rW(dialogueBoxWidths[boxIndex - 1]);
  // 말풍선 높이는 원본 이미지가 전부 60px이므로 rW 기준으로 고정
  final double bubbleHeight = rW(60);

  Widget bubbleImage = Image.asset(
    'assets/images/main_dialogue_box_$boxIndex.png',
    gaplessPlayback: true,
    width: bubbleWidth,
    height: bubbleHeight,
    fit: BoxFit.fill,
  );
  if (isChaeon) {
    bubbleImage = Transform.flip(flipX: true, child: bubbleImage);
  }

  // 채온 말풍선이면 top을 20px 더 내려서 릴리안 말풍선과 겹치지 않게 함
  final double chaeonTopExtra = isChaeon ? 20 : 0;

  return Positioned(
    key: ValueKey('scene_bubble_${node.id}'),
    left: centerX - bubbleWidth / 2,
    top: rH(100 + chaeonTopExtra),
    width: bubbleWidth,
    height: bubbleHeight,
    child: Stack(
      children: [
        bubbleImage,
        // 대사 텍스트: 말풍선 기준 bottom 24, 가로 가운데 정렬
        Positioned(
          left: rW(12),
          right: rW(12),
          bottom: isLargeText ? rW(25) : rW(28),
          child: RichText(
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: visibleSpans),
          ),
        ),
      ],
    ),
  );
}

// 선택지 화면. 검은 반투명(50%) 배경 위에 choice_box를 옵션 개수만큼 가로로 나열, 하단(35)에 표시
Widget buildSceneChoices({
  required DialogueNode node,
  required double Function(double) rW,
  required double Function(double) rH,
  required void Function(DialogueOption option) onChooseOption,
}) {
  const double nativeW = 1264;
  const double nativeH = 240;
  double boxHeight = rW(60);
  double boxWidth = boxHeight * (nativeW / nativeH);
  double gap = rW(16);

  // 옵션이 3개 이상이면 기존 크기 그대로는 화면 밖으로 넘쳐서(overflow) 잘려 보이므로,
  // 한 줄에 다 들어오도록 비율은 유지한 채 축소함. 옵션 2개 이하(기존에 쓰던 화면들)는
  // 아래 조건에 안 걸려서 원래 크기 그대로 나옴
  final double maxRowWidth = rW(834);
  final double naturalRowWidth =
      boxWidth * node.options.length + gap * (node.options.length - 1);
  if (naturalRowWidth > maxRowWidth) {
    final double scale = maxRowWidth / naturalRowWidth;
    boxHeight *= scale;
    boxWidth *= scale;
    gap *= scale;
  }

  return Stack(
    key: ValueKey('scene_choices_${node.id}'),
    children: [
      Positioned.fill(child: Container(color: Colors.black.withOpacity(0.5))),
      Positioned(
        left: 0,
        right: 0,
        bottom: rH(35),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < node.options.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                  child: GestureDetector(
                    onTap: () => onChooseOption(node.options[i]),
                    child: SizedBox(
                      width: boxWidth,
                      height: boxHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/choice_box.png',
                            width: boxWidth,
                            height: boxHeight,
                            fit: BoxFit.fill,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: rW(24)),
                            child: Text(
                              node.options[i].text,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: rW(14),
                                fontWeight: FontWeight.w400,
                                fontFamily: 'SCDream',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
