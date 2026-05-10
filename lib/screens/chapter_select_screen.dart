import 'package:flutter/material.dart';

class ChapterSelectScreen extends StatefulWidget {
  const ChapterSelectScreen({super.key});

  @override
  State<ChapterSelectScreen> createState() => _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends State<ChapterSelectScreen> {
  // 스크롤 위치를 감지하기 위한 컨트롤러
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // 스크롤 할 때마다 하단 바 위치를 계산해서 업데이트함
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
          // 1. 배경 (약간 어둡게 처리된 마을/빵집 배경)
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/main_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. 챕터 리스트 (가로 스크롤)
          Positioned(
            top: rH(40),
            bottom: rH(60),
            left: 0,
            right: 0,
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              // 🔥 핵심 1: BouncingScrollPhysics 추가 (아이폰처럼 끝에서 튕기는 찰진 손맛 추가)
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: rW(80),
              ), // 양옆 여백을 줘서 중앙에 오게 함
              children: [
                _buildChapterCard(
                  "Prolog",
                  "감정을 잃은 사람들",
                  "prolog.png",
                  true,
                  rW,
                  rH,
                ),
                _buildChapterCard(
                  "Chapter 1",
                  "색을 잃은 아이",
                  "ch1.png",
                  false,
                  rW,
                  rH,
                ),
                _buildChapterCard(
                  "Chapter 2",
                  "닫아버린 마음",
                  "ch2.png",
                  false,
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
                // 🔥 핵심 2: 테스트를 위해 더미 챕터 한두 개 더 넣어봐. 안 밀리면 이게 부족한 거야.
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

          // 3. 하단 스크롤 진행 바 (Progress Bar)
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
                // 현재 위치 표시 줄 (움직이는 놈)
                FractionallySizedBox(
                  widthFactor: 0.3, // 바의 전체 길이 중 30% 차지
                  child: Transform.translate(
                    offset: Offset((rW(874 - 200) * 0.7) * _scrollProgress, 0),
                    child: Container(
                      height: rH(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5C18B), // 여친님이 쓴 그 베이지색
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

  // 🖼️ 챕터 카드 위젯
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
            onTap: () {
              if (isUnlocked) {
                print("$title 시작!");
                // 여기서 실제 게임 화면(GameScreen)으로 이동하면 됨!
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
                  // 🔥 핵심: 잠겨있으면 흑백, 풀렸으면 컬러!
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
                border: Border.all(
                  color: isUnlocked
                      ? const Color(0xFFE5C18B)
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
