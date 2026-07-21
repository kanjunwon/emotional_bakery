// lib/features/chapter1/scene_dialogue_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/services/dialogue_loader.dart';

// 대화 그래프를 관리하고, 선택지/대사 진행/온도계 상태를 GamePlayScreen에 전달하는 역할
class SceneDialogueController extends ChangeNotifier {
  SceneDialogueController({
    required this.onDialogueEnd,
    required this.onLillianHop,
    required this.onChaeonHop,
  });

  // 대화 종료, 릴리안 점프, 채온 점프 이벤트를 GamePlayScreen에 전달
  final VoidCallback onDialogueEnd;
  final VoidCallback onLillianHop;
  final VoidCallback onChaeonHop;

  DialogueGraph? sceneDialogue;
  String? sceneNodeId;
  // 선택지 노드로 넘어가도 그 직전 대사 말풍선을 검은 배경 아래에 계속 띄워두기 위해 따로 보관
  DialogueNode? lastLineNode;
  // 선택지 노드로 넘어가기 전까지 지나온 line 노드 히스토리. 뒤로가기 시 이걸 따라감
  final List<String> sceneNodeHistory = [];
  // 선택지를 한 번이라도 골랐는지. 골랐는데 히스토리가 비어서 더 못 돌아갈 때만 안내 배지를 띄움
  bool sceneHasLockedChoice = false;
  String? choiceLockedMessage;
  Timer? _choiceLockedMessageTimer;

  // 온도계 레벨
  int temperature = 3;
  // 온도 변화 안내 문구
  String? temperatureChangeText;
  Timer? _temperatureChangeTimer;

  // 말풍선 타이핑 효과
  Timer? _typingTimer;
  int typedCharCount = 0;
  static const Duration _typingInterval = Duration(milliseconds: 50);

  // 대사 텍스트가 없는 연출용 노드(예: 클로즈업 사이 빈 노드)는 타이핑할 글자가 없어서
  // 진입하자마자 "다 읽었다"고 판단돼, 연속 탭 한 번에 순식간에 지나쳐버릴 수 있음.
  // 최소한 화면에 잠깐 머무르도록 진입 후 일정 시간 동안은 탭으로 넘어가지 못하게 막음
  bool _emptyNodeHoldElapsed = true;
  static const Duration _emptyNodeMinHold = Duration(milliseconds: 500);

  bool _isDisposed = false;

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  // 주어진 경로의 대화 그래프를 불러와서 처음부터 재생 (first_meet/table/first_bread 등 공용)
  Future<void> loadDialogue(String assetPath) async {
    final graph = await DialogueLoader.loadDialogue(assetPath);
    if (_isDisposed) return;
    sceneDialogue = graph;
    sceneNodeHistory.clear();
    sceneHasLockedChoice = false;
    _enterSceneNode(graph.start);
    _notify();
  }

  // line 노드면 온도 효과 바로 적용하고 타이핑 시작, next 없거나 이상한 노드면 대화 종료
  void _enterSceneNode(String? nodeId) {
    _typingTimer?.cancel();
    final graph = sceneDialogue;
    if (nodeId == null || graph == null || !graph.nodes.containsKey(nodeId)) {
      sceneNodeId = null;
      sceneDialogue = null;
      typedCharCount = 0;
      onDialogueEnd();
      return;
    }
    sceneNodeId = nodeId;
    final node = graph.nodes[nodeId]!;
    if (node.type == 'line') {
      lastLineNode = node;
      if (node.temperatureEffect != 0) {
        temperature = (temperature + node.temperatureEffect)
            .clamp(1, 10)
            .toInt();
        _showTemperatureChange(node.temperatureEffect);
        // 선택지를 한 번이라도 골랐으면 되돌아갈 수 없게 히스토리 초기화
        sceneNodeHistory.clear();
        sceneHasLockedChoice = true;
      }
      if (node.animation == 'lillian_hop') {
        onLillianHop();
      } else if (node.animation == 'chaeon_hop') {
        onChaeonHop();
      }
      _startTypingEffect(node);
    } else {
      typedCharCount = 0;
    }
  }

  // 대사 그래프 밖(예: 회상 컷씬 미니게임)에서 온도 변화를 적용할 때 사용
  void applyTemperatureEffect(int effect) {
    if (effect == 0) return;
    temperature = (temperature + effect).clamp(1, 10).toInt();
    _showTemperatureChange(effect);
    _notify();
  }

  // 온도 변화 안내 문구를 잠깐 띄웠다가 2초 뒤 자동으로 닫음
  void _showTemperatureChange(int effect) {
    _temperatureChangeTimer?.cancel();
    final String sign = effect > 0 ? '+' : '';
    final String verb = effect > 0 ? '상승' : '하락';
    temperatureChangeText = '$sign$effect 감정 온도가 $verb했습니다.';
    _temperatureChangeTimer = Timer(const Duration(seconds: 2), () {
      temperatureChangeText = null;
      _notify();
    });
  }

  // 대사를 한 글자씩 순차적으로 드러내는 타이핑 효과 시작
  void _startTypingEffect(DialogueNode node) {
    final int fullLength = node.spans.fold(0, (sum, s) => sum + s.text.length);
    typedCharCount = 0;
    if (fullLength == 0) {
      _emptyNodeHoldElapsed = false;
      _typingTimer = Timer(_emptyNodeMinHold, () {
        _emptyNodeHoldElapsed = true;
        _notify();
      });
      return;
    }
    _typingTimer = Timer.periodic(_typingInterval, (timer) {
      typedCharCount++;
      if (typedCharCount >= fullLength) {
        timer.cancel();
      }
      _notify();
    });
  }

  static List<DialogueSpan> truncateSpans(
    List<DialogueSpan> spans,
    int charCount,
  ) {
    final List<DialogueSpan> result = [];
    int remaining = charCount;
    for (final span in spans) {
      if (remaining <= 0) break;
      if (span.text.length <= remaining) {
        result.add(span);
        remaining -= span.text.length;
      } else {
        result.add(
          DialogueSpan(
            text: span.text.substring(0, remaining),
            color: span.color,
            bold: span.bold,
          ),
        );
        remaining = 0;
      }
    }
    return result;
  }

  // 말풍선 탭하면 다음 노드로. 타이핑 중이면 다음으로 안 넘기고 텍스트 다 보여주기만 함
  void advanceScene() {
    final graph = sceneDialogue;
    final node = (graph != null && sceneNodeId != null)
        ? graph.nodes[sceneNodeId]
        : null;
    if (node == null || node.type != 'line') return;

    final int fullLength = node.spans.fold(0, (sum, s) => sum + s.text.length);
    if (typedCharCount < fullLength) {
      _typingTimer?.cancel();
      typedCharCount = fullLength;
      _notify();
      return;
    }
    // 대사 없는 연출용 노드는 최소 노출 시간이 지나기 전까지 탭으로 못 넘어가게 막음
    if (fullLength == 0 && !_emptyNodeHoldElapsed) return;

    sceneNodeHistory.add(node.id);
    _enterSceneNode(node.next);
    _notify();
  }

  // 선택지 이전 line으로 돌아가기. 히스토리가 비어있으면 안내 배지를 띄움
  void goBackScene() {
    if (sceneNodeHistory.isEmpty) {
      // 선택지를 이미 골라서 그 이전으로 더는 못 돌아갈 때만 안내 배지를 띄움
      if (sceneHasLockedChoice) {
        _showChoiceLockedMessage();
      }
      return;
    }
    final graph = sceneDialogue;
    if (graph == null) return;
    final previousId = sceneNodeHistory.removeLast();
    final previousNode = graph.nodes[previousId];
    if (previousNode == null) return;

    _typingTimer?.cancel();
    sceneNodeId = previousId;
    lastLineNode = previousNode;
    typedCharCount = previousNode.spans.fold<int>(
      0,
      (sum, s) => sum + s.text.length,
    );
    _notify();
  }

  void _showChoiceLockedMessage() {
    _choiceLockedMessageTimer?.cancel();
    choiceLockedMessage = "당신의 선택은 되돌릴 수 없습니다.";
    _notify();
    _choiceLockedMessageTimer = Timer(const Duration(seconds: 2), () {
      choiceLockedMessage = null;
      _notify();
    });
  }

  // 선택지 하나를 골랐을 때 그 선택지의 next로 이동
  void chooseSceneOption(DialogueOption option) {
    // 선택지를 실제로 고른 순간 그 이전 히스토리를 비워서 되돌아갈 수 없게 함
    sceneNodeHistory.clear();
    sceneHasLockedChoice = true;
    _enterSceneNode(option.next);
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _typingTimer?.cancel();
    _temperatureChangeTimer?.cancel();
    _choiceLockedMessageTimer?.cancel();
    super.dispose();
  }
}
