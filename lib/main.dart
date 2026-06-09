import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화

  // 가로 화면 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const EmotionalBakery());
}

// 테스트 환경에서 마우스 드래그 가능
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse, // 마우스 드래그 활성화
  };
}

class EmotionalBakery extends StatelessWidget {
  const EmotionalBakery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 우측 상단 디버그 배너 제거
      scrollBehavior: MyCustomScrollBehavior(), // 커스텀 스크롤 행동
      theme: ThemeData(fontFamily: 'NanumGothic'), // 폰트
      home: const MainScreen(), // 첫 화면 메인화면
    );
  }
}
