// lib/core/services/interaction_loader.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:emotional_bakery/core/models/interaction_model.dart';

class InteractionLoader {
  // 현재 활성화된 배경에 맞는 JSON 파일을 읽어오는 함수
  static Future<List<InteractionObject>> loadStageObjects(
    String bgAssetName,
  ) async {
    String jsonPath = '';

    // 배경 이미지 이름에 따라 읽어올 JSON 파일을 매핑
    if (bgAssetName == 'bakery_bg_main.png') {
      jsonPath = 'assets/data/chapter1/chapter1_bakery.json';
    } else if (bgAssetName == 'kitchen_main.png') {
      jsonPath = 'assets/data/shared/chapter_kitchen.json';
    } else if (bgAssetName == 'room_bg.png') {
      jsonPath = 'assets/data/chapter3/chapter3_room.json';
    } else {
      return []; // 예외 처리
    }

    try {
      final String response = await rootBundle.loadString(jsonPath);
      final List<dynamic> data = json.decode(response);

      // JSON 배열을 Dart 객체 리스트로 파싱해서 반환
      return data.map((obj) => InteractionObject.fromJson(obj)).toList();
    } catch (e) {
      print("JSON 로드 에러: $e");
      return [];
    }
  }
}
