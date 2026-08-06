// lib/features/menu/chapter_select_screen.dart

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/services/chapter_progress.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';
import 'package:emotional_bakery/features/chapter1/game_play_screen.dart';
import 'package:emotional_bakery/features/chapter1/kitchen_screen.dart';
import 'package:emotional_bakery/features/prologue/tutorial_screen.dart';

class ChapterSelectScreen extends StatefulWidget {
  const ChapterSelectScreen({super.key});

  @override
  State<ChapterSelectScreen> createState() => _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends State<ChapterSelectScreen> {
  // 스크롤 위치 감지용 컨트롤러
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  // 챕터 1의 동적 해금 상태를 관리할 상태 변수 선언
  bool _isChapter1Unlocked = false;

  @override
  void initState() {
    super.initState();
    // 스크롤 발생 시 하단 바 위치 계산
    _scrollController.addListener(() {
      setState(() {
        if (_scrollController.hasClients) {
          _scrollProgress =
              _scrollController.offset /
              _scrollController.position.maxScrollExtent;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double rW(double px) => (px / 874) * w;
    double rH(double px) => (px / 402) * h;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 배경 레이어
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/main_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 챕터 리스트 (가로 스크롤)
          Positioned(
            top: rH(40),
            bottom: rH(60),
            left: 0,
            right: 0,
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(), // 끝에서 튕기는 스크롤 효과
              padding: EdgeInsets.symmetric(horizontal: rW(80)), // 양옆 여백
              children: [
                _buildChapterCard(
                  "Prolog",
                  "감정을 잃은 사람들",
                  "ch_prolog.png",
                  true,
                  rW,
                  rH,
                ),
                _buildChapterCard(
                  "Chapter 1",
                  "색을 잃은 아이",
                  "ch1.png",
                  _isChapter1Unlocked, // 동적 상태 변수 반영
                  rW,
                  rH,
                ),
                _buildChapterCard(
                  "Chapter 2",
                  "닫아버린 마음",
                  "ch2.png",
                  ChapterProgress.isChapter2Unlocked, // 챕터1 종료하면 전역으로 해금됨
                  rW,
                  rH,
                ),
                _buildChapterCard(
                  "Chapter 3",
                  "멈춰선 마을",
                  "ch3.png",
                  false,
                  rW,
                  rH,
                ),
                _buildChapterCard(
                  "Chapter 4",
                  "준비 중인 이야기",
                  "ch4.png",
                  false,
                  rW,
                  rH,
                ),
                _buildChapterCard(
                  "Chapter 5",
                  "준비 중인 이야기",
                  "ch5.png",
                  false,
                  rW,
                  rH,
                ),
              ],
            ),
          ),

          // 개발용 임시 버튼 모음. 챕터1~5 화면을 매번 순서대로 안 거치고 바로 테스트하려고
          // 세로로 쌓아둔 지름길 버튼들. 전부 임시 개발용 코드라 나중에 통째로 지울 것
          Positioned(
            right: rW(10),
            bottom: rH(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 챕터1도 잠금이나 프롤로그/튜토리얼 안 거치고 바로 GamePlayScreen으로 진입.
                // 챕터2 버튼처럼 잠금 체크 없이 바로 들어감. 임시 개발용 코드
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const GamePlayScreen(isPrologue: false),
                      ),
                    );
                  },
                  child: Text(
                    "DEV: 챕터1 바로가기",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: rW(10),
                    ),
                  ),
                ),
                SizedBox(height: rH(4)),
                // 개발용 임시 버튼: 챕터2 테스트하려고 프롤로그부터 챕터1 전체를 매번 다시 플레이하기
                // 번거로워서 만든 지름길. 화면 구석에 눈에 안 띄게 작게 배치. 나중에 지울 코드
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const KitchenScreen(mode: KitchenScreenMode.chapter2Start),
                      ),
                    );
                  },
                  child: Text(
                    "DEV: 챕터2 바로가기",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: rW(10),
                    ),
                  ),
                ),
                SizedBox(height: rH(4)),
                // 챕터3/4/5는 화면 자체가 아직 없어서 이동하면 에러남. 탭하면 화면 전환 없이
                // 스낵바로 미구현 안내만 잠깐 띄우고 끝냄. 임시 개발용 코드
                _buildDevUnimplementedButton("DEV: 챕터3 바로가기", "챕터3 아직 미구현", rW),
                SizedBox(height: rH(4)),
                _buildDevUnimplementedButton("DEV: 챕터4 바로가기", "챕터4 아직 미구현", rW),
                SizedBox(height: rH(4)),
                _buildDevUnimplementedButton("DEV: 챕터5 바로가기", "챕터5 아직 미구현", rW),
              ],
            ),
          ),

          // 하단 스크롤 진행 바
          Positioned(
            bottom: rH(30),
            left: rW(100),
            right: rW(100),
            child: Stack(
              children: [
                // 바닥 배경 줄
                Container(
                  height: rH(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 현재 위치 표시 줄 (움직이는 바)
                FractionallySizedBox(
                  widthFactor: 0.3,
                  child: Transform.translate(
                    offset: Offset((rW(874 - 200) * 0.7) * _scrollProgress, 0),
                    child: Container(
                      height: rH(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5C18B), // 베이지색 포인트 컬러
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 아직 화면이 없는 챕터용 임시 개발 버튼. 탭해도 이동 안 하고 스낵바로 미구현 안내만 잠깐 띄움.
  // 나중에 챕터3/4/5 화면 생기면 이 버튼도 같이 지울 것
  Widget _buildDevUnimplementedButton(
    String label,
    String snackBarMessage,
    double Function(double) rW,
  ) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackBarMessage),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: rW(10)),
      ),
    );
  }

  // 챕터 카드 위젯
  Widget _buildChapterCard(
    String title,
    String subTitle,
    String imgName,
    bool isUnlocked,
    Function rW,
    Function rH,
  ) {
    return Padding(
      padding: EdgeInsets.only(right: rW(40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: rW(24),
              fontWeight: FontWeight.bold,
              fontFamily: 'NanumGothic',
            ),
          ),
          Text(
            subTitle,
            style: TextStyle(color: Colors.white70, fontSize: rW(14)),
          ),
          SizedBox(height: rH(15)),
          GestureDetector(
            onTap: () async {
              if (isUnlocked) {
                if (title == "Prolog") {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const GamePlayScreen(isPrologue: true),
                    ),
                  );

                  if (result == true) {
                    setState(() {
                      _isChapter1Unlocked = true;
                    });
                    print("챕터 1 잠금장치가 해제되었습니다!");
                  }
                } else if (title == "Chapter 1") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TutorialScreen(),
                    ),
                  );
                } else if (title == "Chapter 2") {
                  // 챕터2는 빵집/튜토리얼 없이 바로 주방 화면(챕터2 시작 모드)에서 시작
                  Navigator.push(
                    context,
                    fadeThroughBlackRoute(
                      const KitchenScreen(
                        mode: KitchenScreenMode.chapter2Start,
                      ),
                    ),
                  );
                }
              } else {
                print("잠겨있음!");
              }
            },
            child: Container(
              width: rW(220),
              height: rH(220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                image: DecorationImage(
                  image: AssetImage('assets/images/$imgName'),
                  fit: BoxFit.cover,
                  // 잠겨있으면 흑백, 풀렸으면 컬러 처리
                  colorFilter: isUnlocked
                      ? null
                      : const ColorFilter.matrix([
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
