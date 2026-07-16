// lib/features/menu/choice_screen.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/features/menu/chapter_select_screen.dart';

class ChoiceScreen extends StatefulWidget {
  const ChoiceScreen({super.key});

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> {
  // 현재 눌려있는 버튼의 인덱스 (0: 없음, 1: 시작, 2: 이어, 3: 설정)
  int _pressedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 874x402 기준 반응형 좌표 함수
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Image.asset('assets/images/main_bg.png', fit: BoxFit.cover),

          Positioned(
            left: rW(91), // X축 위치
            top: rH(38), // Y축 위치
            child: Image.asset(
              'assets/images/logo.png',
              width: rW(167), // 로고 크기
              fit: BoxFit.contain,
            ),
          ),

          // 시작하기 버튼
          Positioned(
            left: rW(100), // X축 위치
            top: rH(195), // Y축 위치
            width: rW(144), // 버튼 크기
            child: _imageMenuButton(
              index: 1,
              normalImg: 'start.png',
              touchImg: 'start_touch.png',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChapterSelectScreen(),
                  ),
                );
              },
              rW: rW,
              rH: rH,
            ),
          ),

          // 이어하기 버튼
          Positioned(
            left: rW(100), // X축 위치
            top: rH(261), // Y축 위치
            width: rW(144), // 버튼 크기
            child: _imageMenuButton(
              index: 2,
              normalImg: 'continued.png',
              touchImg: 'continued_touch.png',
              onPressed: () => print("이어하기 클릭!"),
              rW: rW,
              rH: rH,
            ),
          ),

          // 게임 설정 버튼
          Positioned(
            left: rW(100), // X축 위치
            top: rH(327), // Y축 위치
            width: rW(144), // 버튼 크기
            child: _imageMenuButton(
              index: 3,
              normalImg: 'setting.png',
              touchImg: 'setting_touch.png',
              onPressed: () => print("설정 클릭!"),
              rW: rW,
              rH: rH,
            ),
          ),
        ],
      ),
    );
  }

  // 이미지 전용 버튼 위젯 함수
  Widget _imageMenuButton({
    required int index,
    required String normalImg,
    required String touchImg,
    required VoidCallback onPressed,
    required Function rW,
    required Function rH,
  }) {
    bool isPressed = (_pressedIndex == index);

    return Padding(
      padding: EdgeInsets.only(bottom: rH(10)), // rH로 비율 유지
      child: GestureDetector(
        // 터치하는 순간 이미지 교체
        onTapDown: (_) => setState(() => _pressedIndex = index),
        // 터치 떼는 순간 원래대로 + 기능 실행
        onTapUp: (_) {
          setState(() => _pressedIndex = 0);
          onPressed();
        },
        // 누르다가 밖으로 삐져나가면 취소
        onTapCancel: () => setState(() => _pressedIndex = 0),

        child: Image.asset(
          'assets/images/${isPressed ? touchImg : normalImg}',
          width: rW(220),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
