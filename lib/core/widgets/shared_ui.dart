// lib/core/widgets/shared_ui.dart
// 튜토리얼/챕터1 화면에서 같이 쓰는 대사창, 가상 패드 버튼 공용 위젯

import 'package:flutter/material.dart';

// 페이드아웃 300ms -> 완전 검은 화면 유지 1000ms -> 페이드인 300ms, 총 1600ms
const Duration _fadeThroughBlackFadeOut = Duration(milliseconds: 150);
const Duration _fadeThroughBlackHold = Duration(milliseconds: 800);
const Duration _fadeThroughBlackFadeIn = Duration(milliseconds: 300);
final Duration _fadeThroughBlackTotal =
    _fadeThroughBlackFadeOut + _fadeThroughBlackHold + _fadeThroughBlackFadeIn;

PageRouteBuilder fadeThroughBlackRoute(Widget page) {
  final double fadeOutEnd =
      _fadeThroughBlackFadeOut.inMilliseconds /
      _fadeThroughBlackTotal.inMilliseconds;
  final double holdEnd =
      (_fadeThroughBlackFadeOut + _fadeThroughBlackHold).inMilliseconds /
      _fadeThroughBlackTotal.inMilliseconds;

  // 페이지 전환 시, 화면이 검은색으로 페이드아웃 -> 잠시 유지 -> 페이드인 되도록 하는 커스텀 트랜지션
  return PageRouteBuilder(
    transitionDuration: _fadeThroughBlackTotal,
    reverseTransitionDuration: _fadeThroughBlackTotal,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final double v = animation.value;
      final double blackOpacity;
      final double childOpacity;
      if (v < fadeOutEnd) {
        blackOpacity = v / fadeOutEnd;
        childOpacity = 0.0;
      } else if (v < holdEnd) {
        blackOpacity = 1.0;
        childOpacity = 1.0;
      } else {
        blackOpacity = 1.0 - (v - holdEnd) / (1.0 - holdEnd);
        childOpacity = 1.0;
      }
      return Stack(
        children: [
          Opacity(opacity: childOpacity, child: child),
          IgnorePointer(
            child: Opacity(
              opacity: blackOpacity.clamp(0.0, 1.0),
              child: Container(color: Colors.black),
            ),
          ),
        ],
      );
    },
  );
}

// 대사창 텍스트 공통 스타일
TextStyle dialogueTextStyle(double Function(double) rW) {
  return TextStyle(
    color: const Color(0xFF5A3E2B),
    fontSize: rW(13),
    height: 1.5,
    fontWeight: FontWeight.w500,
    fontFamily: 'SCDream',
  );
}

// 대사창 프레임. 튜토리얼 안내/오브젝트 정보 팝업이 공용으로 씀
class DialogueBoxFrame extends StatelessWidget {
  final Widget textWidget;
  final double Function(double) rW;
  final double Function(double) rH;

  const DialogueBoxFrame({
    super.key,
    required this.textWidget,
    required this.rW,
    required this.rH,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: rW(20), vertical: rH(15)),
        constraints: BoxConstraints(
          minWidth: rW(180),
          maxWidth: rW(500),
          minHeight: rH(70),
        ),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/tutorial_dialogue_box.png'),
            fit: BoxFit.fill,
            centerSlice: Rect.fromLTRB(5, 5, 1114, 280),
          ),
        ),
        // 텍스트와 화살표를 겹치지 않게 배치
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 텍스트 위젯
            Padding(
              padding: EdgeInsets.fromLTRB(rW(20), 0, rW(20), 0),
              child: textWidget,
            ),
            Positioned(
              right: rW(0),
              bottom: rH(7),
              child: Image.asset(
                'assets/images/tutorial_arrow.png',
                width: rW(12),
                height: rH(10),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 대사창을 화면 중앙에 띄우는 위젯. 튜토리얼 안내/오브젝트 정보 팝업이 공용으로 씀
class CenteredDialogueBox extends StatelessWidget {
  final Widget textWidget;
  final double Function(double) rW;
  final double Function(double) rH;

  const CenteredDialogueBox({
    super.key,
    required this.textWidget,
    required this.rW,
    required this.rH,
  });

  // 화면 중앙에 대사창을 띄움. 튜토리얼 안내/오브젝트 정보 팝업이 공용으로 씀
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.2),
      child: DialogueBoxFrame(textWidget: textWidget, rW: rW, rH: rH),
    );
  }
}

// 가상 패드 버튼 (좌우 이동 공용)
class DpadButton extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback? onTapCancel;
  final double Function(double) rW;
  final double Function(double) rH;

  const DpadButton({
    super.key,
    required this.imagePath,
    required this.onTapDown,
    required this.onTapUp,
    this.onTapCancel,
    required this.rW,
    required this.rH,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel ?? onTapUp, // 버튼 밖으로 손가락이 미끄러져 나가도 멈추도록 예외 처리
      child: Container(
        width: rW(64),
        height: rH(64),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
