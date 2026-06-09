// lib/screens/game_play_screen.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/bakery_game.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  // Flame 게임 인스턴스 생성
  final BakeryGame _game = BakeryGame();

  @override
  Widget build(BuildContext context) {
    // 874x402 기준 반응형 함수
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),

          // 왼쪽 이동 버튼 오버레이
          Positioned(
            left: rW(650), // 피그마 좌표 확인하기
            bottom: rH(20),
            child: GestureDetector(
              onTapDown: (_) => _game.movePlayer(-1), // 누르면 왼쪽 이동
              onTapUp: (_) => _game.movePlayer(0), // 떼면 정지
              onTapCancel: () => _game.movePlayer(0),
              child: Container(
                width: rW(60),
                height: rH(60),
                color: Colors.transparent, // 투명하게 만들어서 배경의 도트 버튼 클릭 효과 냄
              ),
            ),
          ),

          // 오른쪽 이동 버튼 오버레이
          Positioned(
            left: rW(730), // 피그마 좌표 확인하기
            bottom: rH(20),
            child: GestureDetector(
              onTapDown: (_) => _game.movePlayer(1), // 누르면 오른쪽 이동
              onTapUp: (_) => _game.movePlayer(0), // 떼면 정지
              onTapCancel: () => _game.movePlayer(0),
              child: Container(
                width: rW(60),
                height: rH(60),
                color: Colors.transparent,
              ),
            ),
          ),

          // 상단 UI(하트, 메뉴 버튼 등)도 여기에 Positioned로 추가
        ],
      ),
    );
  }
}
