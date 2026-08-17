// lib/core/models/dialogue_node.dart
// 채온-릴리안 대화 그래프(JSON) 파싱 모델

import 'package:flutter/material.dart';

// 대사 하나, 색/굵기 다른 구간 섞인 텍스트 표현용
class DialogueSpan {
  final String text;
  final Color? color;
  final bool bold;
  final double? size;

  DialogueSpan({required this.text, this.color, this.bold = false, this.size});
}

// 릴리안 표현(스프라이트) 오버라이드. asset만 있으면 정지 이미지, durationMs/autoAdvance까지 있으면
// GIF 재생 후 자동으로 다음 노드로 넘어가는 경우 (scene_dialogue_controller.dart에서 사용)
class DialogueExpression {
  final String asset;
  final int? durationMs;
  final bool autoAdvance;

  DialogueExpression({
    required this.asset,
    this.durationMs,
    this.autoAdvance = false,
  });
}

// choice 노드의 선택지 하나
class DialogueOption {
  final String text;
  final String next;
  // 이 선택지를 고르면 저장할 변수들 (예: {"q1": "eat"}). 없으면 null
  final Map<String, dynamic>? setVars;

  DialogueOption({required this.text, required this.next, this.setVars});
}

// 그래프의 노드 하나 (대사 한 줄 또는 분기 선택지)
class DialogueNode {
  final String id;
  final String type; // 'line' | 'choice'
  final String? speaker; // 'chaeon' | 'lillian' (type == 'line'일 때만)
  final List<DialogueSpan> spans; // type == 'line'일 때만
  final int temperatureEffect; // type == 'line'일 때만
  final String? next; // type == 'line'일 때만. null이면 대화 종료
  final List<DialogueOption> options; // type == 'choice'일 때만
  final String? animation; // type == 'line'일 때만. 캐릭터 모션 트리거용 (예: "lillian_hop")
  final DialogueExpression? expression; // type == 'line'일 때만. 릴리안 스프라이트 오버라이드

  DialogueNode({
    required this.id,
    required this.type,
    this.speaker,
    this.spans = const [],
    this.temperatureEffect = 0,
    this.next,
    this.options = const [],
    this.animation,
    this.expression,
  });

  factory DialogueNode.fromJson(String id, Map<String, dynamic> json) {
    final String type = json['type'] as String;

    if (type == 'choice') {
      final optionsJson = json['options'] as List<dynamic>;
      return DialogueNode(
        id: id,
        type: type,
        options: optionsJson
            .map(
              (o) => DialogueOption(
                text: o['text'] as String,
                next: o['next'] as String,
                setVars: (o['setVars'] as Map?)?.cast<String, dynamic>(),
              ),
            )
            .toList(),
      );
    }

    // text는 일반 문자열이거나, {text, color, bold} 배열(리치 텍스트)일 수 있음
    final List<DialogueSpan> spans = [];
    final rawText = json['text'];
    if (rawText is String) {
      spans.add(DialogueSpan(text: rawText));
    } else if (rawText is List) {
      for (final part in rawText) {
        final map = part as Map<String, dynamic>;
        Color? color;
        final colorHex = map['color'] as String?;
        if (colorHex != null) {
          final hex = colorHex.replaceFirst('#', '');
          color = Color(int.parse('FF$hex', radix: 16));
        }
        spans.add(
          DialogueSpan(
            text: map['text'] as String,
            color: color,
            bold: map['bold'] == true,
            size: (map['size'] as num?)?.toDouble(),
          ),
        );
      }
    }

    int temperatureEffect = 0;
    final effect = json['effect'];
    if (effect is Map && effect['temperature'] != null) {
      temperatureEffect = (effect['temperature'] as num).toInt();
    }

    // "다음 대사 없음"을 문자열 null로 적어둔 경우
    String? next = json['next'] as String?;
    if (next == 'null') next = null;

    // 문자열이면 정지 이미지, 객체({asset, durationMs, autoAdvance})면 GIF+자동진행 표현
    DialogueExpression? expression;
    final rawExpression = json['expression'];
    if (rawExpression is String) {
      expression = DialogueExpression(asset: rawExpression);
    } else if (rawExpression is Map) {
      expression = DialogueExpression(
        asset: rawExpression['asset'] as String,
        durationMs: (rawExpression['durationMs'] as num?)?.toInt(),
        autoAdvance: rawExpression['autoAdvance'] == true,
      );
    }

    return DialogueNode(
      id: id,
      type: type,
      speaker: json['speaker'] as String?,
      spans: spans,
      temperatureEffect: temperatureEffect,
      next: next,
      animation: json['animation'] as String?,
      expression: expression,
    );
  }
}

// 대화 그래프 전체 (시작 노드 + 노드 맵)
class DialogueGraph {
  final String dialogueId;
  final String start;
  final Map<String, DialogueNode> nodes;

  DialogueGraph({
    required this.dialogueId,
    required this.start,
    required this.nodes,
  });
}
