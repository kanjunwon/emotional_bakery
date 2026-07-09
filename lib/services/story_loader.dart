// JSON 로더 서비스

import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/models/scene_model.dart';

class StoryLoader {
  // JSON 파일을 읽어서 Scene 리스트로 반환하는 함수
  static Future<List<Scene>> loadStory() async {
    // 1. 파일 읽기
    final String response = await rootBundle.loadString(
      'assets/data/story.json',
    );
    // 2. JSON 파싱
    final List<dynamic> data = json.decode(response);
    // 3. 객체 리스트로 변환
    return data.map((json) => Scene.fromJson(json)).toList();
  }
}
