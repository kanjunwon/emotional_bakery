// lib/features/chapter1/game_play_screen.dart

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../game/bakery_game.dart';
import '../../core/widgets/dialogue_overlay.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  final BakeryGame _game = BakeryGame();

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    return Scaffold(
      body: Stack(
        children: [
          // 1층: 게임 엔진 및 오버레이 설정 구역
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              // 프롤로그 오버레이 위젯 등록
              'dialogue': (BuildContext context, BakeryGame game) {
                return DialogueOverlay(game: game);
              },
            },
            // 게임 시작 시 프롤로그 오버레이를 최상단에 강제 활성화
            initialActiveOverlays: const ['dialogue'],
          ),

          // 2층: 가상 패드 왼쪽 버튼 영역
          Positioned(
            left: rW(650),
            bottom: rH(20),
            child: GestureDetector(
              onTapDown: (_) => _game.movePlayer(-1),
              onTapUp: (_) => _game.movePlayer(0),
              onTapCancel: () => _game.movePlayer(0),
              child: Container(
                width: rW(60),
                height: rH(60),
                color: Colors.transparent,
              ),
            ),
          ),

          // 3층: 가상 패드 오른쪽 버튼 영역
          Positioned(
            left: rW(730),
            bottom: rH(20),
            child: GestureDetector(
              onTapDown: (_) => _game.movePlayer(1),
              onTapUp: (_) => _game.movePlayer(0),
              onTapCancel: () => _game.movePlayer(0),
              child: Container(
                width: rW(60),
                height: rH(60),
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
