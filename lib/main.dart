// lib/main.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/models/scene_model.dart';
import 'package:emotional_bakery/services/story_loader.dart';

void main() {
  runApp(const EmotionalBakery());
}

class EmotionalBakery extends StatelessWidget {
  const EmotionalBakery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 디버그 배너 제거
      theme: ThemeData(fontFamily: 'NanumGothic'),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Future<List<Scene>> _storyFuture;
  int _currentSceneIndex = 0; // 현재 몇 번째 장면인지 관리하는 변수

  @override
  void initState() {
    super.initState();
    _storyFuture = StoryLoader.loadStory();
  }

  // 화면 아무 데나 터치했을 때 다음 장면으로 넘어가는 함수
  void _nextScene(List<Scene> scenes) {
    setState(() {
      if (_currentSceneIndex < scenes.length - 1) {
        _currentSceneIndex++;
      } else {
        // 마지막 장면이면? (나중에 엔딩 처리)
        print("챕터 끝!");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Scene>>(
        future: _storyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("에러 시발 : ${snapshot.error}")); // 에러 처리
          } else {
            final scenes = snapshot.data!;
            final currentScene = scenes[_currentSceneIndex];

            // GestureDetector로 감싸서 터치 인식하게 만듦
            return GestureDetector(
              onTap: () => _nextScene(scenes), // 터치하면 다음 장면
              child: Stack(
                // 레이어를 겹겹이 쌓는 Stack 위젯
                fit: StackFit.expand, // 화면 꽉 채우기
                children: [
                  // 1층: 배경 레이어 (나중에 이미지로 교체)
                  Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Text(
                        "배경: ${currentScene.background}",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),

                  // 2층: 캐릭터 레이어 (나중에 투명 PNG로 교체)
                  Positioned(
                    bottom: 150, // 대사창 위에 살짝 걸치게
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 400,
                        color: Colors.blueAccent.withOpacity(0.5), // 반투명 파란색
                        child: Center(
                          child: Text(
                            "캐릭터: ${currentScene.character}",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3층: 감정 온도계 UI (임시)
                  Positioned(
                    top: 50,
                    right: 20,
                    child: Container(
                      width: 30,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 30,
                          height: 100, // 높이를 변수로 변경 예정
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4층: 대사창 레이어
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 120,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7), // 반투명 검은색
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        currentScene.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
