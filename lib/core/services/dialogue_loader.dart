// lib/core/services/dialogue_loader.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';

class DialogueLoader {
  // assets/lines/... 경로의 대화 그래프 JSON을 읽어 DialogueGraph로 변환
  static Future<DialogueGraph> loadDialogue(String assetPath) async {
    final String raw = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> data = json.decode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> nodesJson =
        data['nodes'] as Map<String, dynamic>;

    final Map<String, DialogueNode> nodes = nodesJson.map(
      (key, value) => MapEntry(
        key,
        DialogueNode.fromJson(key, value as Map<String, dynamic>),
      ),
    );

    return DialogueGraph(
      dialogueId: data['dialogue_id'] as String,
      start: data['start'] as String,
      nodes: nodes,
    );
  }
}
