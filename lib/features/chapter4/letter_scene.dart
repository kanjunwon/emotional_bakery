// lib/features/chapter4/letter_scene.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

// 챕터4에서 채온이가 엄마 편지를 읽는 컷씬. dialogue_overlay.dart처럼 화면 전체를
// 덮고 탭으로 진행하는 구조를 그대로 따르긴 하는데, 여긴 이전 줄이 사라지는 대신
// 편지 줄이 계속 아래로 쌓이면서 보이는 게 다름
class LetterScene extends StatefulWidget {
  final VoidCallback onComplete;

  const LetterScene({super.key, required this.onComplete});

  @override
  State<LetterScene> createState() => _LetterSceneState();
}

class _LetterSceneState extends State<LetterScene> {
  // letter_bg.png 원본이 3496x2080이라 874 기준 레퍼런스 프레임은 정확히 874x520(3496/4, 2080/4).
  // 편지 시작 지점(85, 64)은 이 레퍼런스 프레임 기준 좌표
  static const double _bgRefWidth = 874;
  static const double _bgRefHeight = 520;
  static const double _letterStartXRef = 85;
  static const double _letterStartYRef = 64;
  // 폰트 크기/아이콘 크기/문단 여백도 배경 기준(874x520) 레퍼런스 값. 배경이랑 똑같은
  // containScale로 키워야, 배경 줄 간격이 늘어나거나 줄어들 때 글자도 같이 늘어나거나
  // 줄어들어서 계속 줄에 맞음
  static const double _letterFontSizeRef = 14;
  static const double _letterIconSizeRef = 20;
  static const double _letterParagraphGapRef = 28;
  // 배경+글씨 덩어리 자체를 화면에 딱 맞는 크기보다 조금 더 키우고 싶을 때 쓰는 배율.
  // 1보다 크게 잡으면 화면 비율에 따라 배경 가장자리가 살짝 잘릴 수 있음(원본 비율은 유지됨)
  static const double _letterZoomFactor = 1.2;

  // 편지 원문. 원본엔 12번째 줄("사랑해, 우리 채온.") 앞에 문단 구분용 빈 줄이 있었는데,
  // 그건 별도 탭 없이 렌더링할 때 인덱스 11 앞에 여백만 끼워주는 걸로 처리함
  static const List<String> _letterLines = [
    '채온아,',
    '이 편지를 쓰는 지금, 엄마는 네가 자는 걸 보고 있어.',
    '조용히 숨을 쉬고, 작은 손을 꼭 쥐고 자는 너를 보면서',
    '엄마는 한참을 울었단다.',
    '엄마가 곁에 없어도, 너무 무서워하지 마.',
    '네가 아침에 눈을 뜰 때도, 밥을 먹을 때도, 혼자서 긴 하루를 버텨낼 때도,',
    '엄마는 항상 네 옆에 있을 거야.',
    '보이지 않아도, 항상.',
    '채온아, 엄마한테 너는 너무나도 소중한 채온이야.',
    '강한 날도, 너무 힘들어서 무너지는 날도, 엄마 눈엔 언제나 똑같이 소중해.',
    '어떤 모습이어도, 엄마가 너를 사랑하는 마음은 변하지 않아.',
    '사랑해, 우리 채온.',
    '엄마가.',
  ];

  // 지금까지 공개된 줄 수. 처음엔 1줄만 보이다가 탭할 때마다 하나씩 늘어남
  int _revealedCount = 1;

  void _handleTap() {
    if (_revealedCount < _letterLines.length) {
      setState(() => _revealedCount++);
    } else {
      // 마지막 줄까지 다 공개된 상태에서 한 번 더 탭하면 여기서 끝
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    // 배경이랑 글씨를 따로 스케일링하면 화면 비율마다 어긋나는 문제가 있어서, 배경을
    // BoxFit.cover 대신 BoxFit.contain으로 원본 비율 그대로(잘리지 않게) 축소/확대하고,
    // 남는 공간은 흰 배경(Container color)이 채우게 함. 이러면 배경 이미지와 글씨가
    // 항상 똑같은 배율(containScale) 하나로만 커지고 작아지니까 절대 어긋날 수가 없음
    final containScale =
        math.min(w / _bgRefWidth, h / _bgRefHeight) * _letterZoomFactor;
    final bgAnchorX = (w - _bgRefWidth * containScale) / 2;
    final bgAnchorY = (h - _bgRefHeight * containScale) / 2;
    final letterStartX = bgAnchorX + _letterStartXRef * containScale;
    final letterStartY = bgAnchorY + _letterStartYRef * containScale;
    // 오른쪽 여백은 시작 지점(85)과 대칭이라고 보고 그대로 미러링함
    final letterEndMargin = bgAnchorX + _letterStartXRef * containScale;
    // 배경 기준(874x520) 픽셀을 실제 화면 픽셀로 옮길 때 쓰는 배율. 폰트/아이콘/문단
    // 여백도 이걸로 키워야 배경 줄 간격이랑 계속 맞음
    double bgScale(double px) => px * containScale;

    final textStyle = TextStyle(
      fontFamily: 'SCDream',
      fontWeight: FontWeight.w500,
      fontSize: bgScale(_letterFontSizeRef),
      height: 2.02,
      color: const Color(0xFF451805),
    );

    // 공개된 줄만큼 위젯을 쌓고, 제일 마지막 줄에만 진행 안내 아이콘을 붙여줌
    final lineWidgets = <Widget>[];
    for (var i = 0; i < _revealedCount; i++) {
      // 12번째 줄(인덱스 11) 앞 문단 구분 여백
      if (i == 11) {
        lineWidgets.add(SizedBox(height: bgScale(_letterParagraphGapRef)));
      }
      final isLastRevealedLine = i == _revealedCount - 1;
      if (!isLastRevealedLine) {
        lineWidgets.add(Text(_letterLines[i], style: textStyle));
      } else {
        lineWidgets.add(
          Text.rich(
            TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: _letterLines[i]),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: const Color(0xFF451805),
                    size: bgScale(_letterIconSizeRef),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: w,
        height: h,
        color: Colors.white,
        child: Stack(
          children: [
            Positioned(
              left: bgAnchorX,
              top: bgAnchorY,
              width: _bgRefWidth * containScale,
              height: _bgRefHeight * containScale,
              child: Image.asset('assets/images/letter_bg.png'),
            ),
            Positioned(
              left: letterStartX,
              top: letterStartY,
              right: letterEndMargin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lineWidgets,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
