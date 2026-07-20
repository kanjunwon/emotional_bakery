// lib/features/chapter1/game_play_widgets.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/scene_dialogue_controller.dart';

// 채온이 빵 먹는 장면에서 전체화면 클로즈업으로 보여주는 GIF. table.json 대사 구간에서만 표시
const List<String> eatingCloseupNodeIds = [
  'line_004a1',
  'line_004a2',
  'line_004a3',
  'line_004b2',
  'line_004b3',
];

class EatingCloseupOverlay extends StatefulWidget {
  const EatingCloseupOverlay({super.key});

  @override
  State<EatingCloseupOverlay> createState() => _EatingCloseupOverlayState();
}

class _EatingCloseupOverlayState extends State<EatingCloseupOverlay> {
  static const List<String> _frames = [
    'assets/images/chaeon_eating_1.png',
    'assets/images/chaeon_eating_2.png',
  ];

  int _frameIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Image.asset(
          _frames[_frameIndex],
          key: ValueKey(_frames[_frameIndex]),
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
  final double boxHeight = rW(60);
  final double boxWidth = boxHeight * (nativeW / nativeH);
  final double gap = rW(16);

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
