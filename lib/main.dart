// 메인페이지

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:emotional_bakery/models/scene_model.dart';
import 'package:emotional_bakery/services/story_loader.dart';
import 'screens/main_screen.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화
  // 가로 화면 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const EmotionalBakery());
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // 마우스 드래그도 인식하도록 스크롤 행동 커스터마이징
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse, // 마우스 드래그 기기 추가
  };
}

class EmotionalBakery extends StatelessWidget {
  const EmotionalBakery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 디버그 배너 제거
      // 커스텀 스크롤 동작
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData(fontFamily: 'NanumGothic'), // 폰트
      home: const MainScreen(), // 시작은 메인화면
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
  late List<Scene> _allScenes; // 전체 스토리 데이터를 저장할 변수
  String _currentSceneId = "start"; // 시작 장면 ID
  int _emotionScore = 0; // 감정 온도계 기본값

  @override
  void initState() {
    super.initState();
    _storyFuture = StoryLoader.loadStory().then((scenes) {
      _allScenes = scenes;
      return scenes;
    });
  }

  // ID를 기반으로 다음 장면으로 이동하는 함수
  void _goToScene(String nextId, {int emotionDelta = 0}) {
    setState(() {
      _currentSceneId = nextId;
      _emotionScore += emotionDelta; // 감정 점수 업데이트!

      // (테스트용) 점수 잘 바뀌는지 터미널에 찍어보기
      print("이동: $nextId / 현재 온도: $_emotionScore");
    });
  }

  // lib/main.dart

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Scene>>(
        future: _storyFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          // 현재 ID에 해당하는 장면 데이터 찾기
          final currentScene = _allScenes.firstWhere(
            (s) => s.id == _currentSceneId,
            orElse: () => _allScenes.first, // 못 찾으면 첫 번째 씬 보여줌
          );

          // 반응형 LayoutBuilder
          return LayoutBuilder(
            builder: (context, constraints) {
              // 화면의 실제 너비와 높이를 가져와서 변수에 담기
              double w = constraints.maxWidth;
              double h = constraints.maxHeight;

              return GestureDetector(
                // 선택지가 없을 때만 화면 터치로 넘어감
                onTap: () {
                  if (currentScene.choices == null &&
                      currentScene.nextId != null) {
                    _goToScene(currentScene.nextId!);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1층: 배경 레이어
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/${currentScene.background}.png', // JSON의 배경파일명 사용
                        fit: BoxFit.cover,
                      ),
                    ),

                    // 2층: 캐릭터 레이어 (중앙 배치)
                    Align(
                      alignment: const Alignment(0, 0.3), // x축 중앙, y축은 살짝 아래
                      child: Image.asset(
                        'assets/images/${currentScene.character}.png', // JSON의 캐릭터파일명 사용
                        width: w * 0.8, // 화면 너비의 80% 크기 (반응형)
                      ),
                    ),

                    // 3층: 감정 온도계 UI (임시 위치에서 실제 에셋 위치로 미세조정)
                    Positioned(
                      top: h * 0.05, // 화면 높이의 5% 지점
                      right: w * 0.05, // 화면 너비의 5% 지점
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // 온도계 틀 이미지 (여기에 에셋 넣어!)
                          Image.asset(
                            'assets/images/thermometer.png',
                            height: h * 0.3,
                          ),
                          Container(width: w * 0.08, height: h * 0.3),
                        ],
                      ),
                    ),

                    // 4층: 대사창 레이어
                    Positioned(
                      bottom: h * 0.03, // 하단 3% 여백 (반응형)
                      left: w * 0.05, // 좌우 5% 여백 (반응형)
                      right: w * 0.05,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 대사창 이미지 에셋 (여기에 넣어!)
                          Image.asset('assets/images/dialogue_box.png'),
                          // 실제 대사 텍스트
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              currentScene.text,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w * 0.05, // 폰트 크기도 화면 너비에 비례 (반응형)
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 5층: 선택지 레이어 (선택지가 있을 때만 뿅 나타남!)
                    if (currentScene.choices != null)
                      Positioned(
                        top: h * 0.3, // 화면 중간쯤 (반응형)
                        left: w * 0.15,
                        right: w * 0.15,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: currentScene.choices!.map((choice) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15.0),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.brown[400], // 여친님 빵집 컨셉 색깔
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: const BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  // 🔥 버튼 누르면 해당 ID로 쓩! 온도도 변함!
                                  _goToScene(
                                    choice.nextId,
                                    emotionDelta: choice.emotionDelta,
                                  );
                                },
                                child: Center(
                                  child: Text(
                                    choice.text,
                                    style: TextStyle(
                                      fontSize: w * 0.045,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
