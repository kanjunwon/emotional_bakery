// lib/features/chapter1/scene_dialogue_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:emotional_bakery/core/models/dialogue_node.dart';
import 'package:emotional_bakery/core/services/dialogue_loader.dart';
import 'package:emotional_bakery/core/services/gif_duration.dart';
import 'package:emotional_bakery/core/services/story_state.dart';

// first_bread.json에서만 쓰는 dialogue_id. table.json도 line_001/line_002라는 같은
// 노드ID를 쓰기 때문에, 노드ID만 보고 지연 로직을 걸면 table.json에서도 오작동함
const String _bubbleDelayDialogueId = 'chapter1_first_bread';

// 이 노드에 진입하면 대사창을 바로 안 띄우고, 여기 적힌 GIF가 다 재생될 때까지 기다렸다가 띄움.
// game_play_widgets.dart의 chaeonSpriteOverrides랑 같은 GIF를 가리키니 값 바꿀 때 같이 맞춰줘야 함
const Map<String, String> _bubbleDelayGifByNodeId = {
  'line_001': 'assets/images/chaeon_emotion_0to100.gif',
  'line_002': 'assets/images/chaeon_emotion_100to0.gif',
};

// first_meet.json에서만 쓰는 dialogue_id
const String _autoAdvanceDialogueId = 'chapter1_first_meet';

// 이 노드에 진입하면 대사 없이 GIF만 한 번 재생되고, 끝나면 유저 탭 없이 자동으로 다음 노드로 넘어감.
// game_play_widgets.dart의 lillianSpriteOverrides랑 같은 GIF를 가리키니 값 바꿀 때 같이 맞춰줘야 함
const Map<String, String> _autoAdvanceGifByNodeId = {
  'line_029a6_eat': 'assets/images/lillian_eating_bread.gif',
  'line_029a6_cry': 'assets/images/lillian_crying.gif',
};

// 위 GIF들은 실제 재생 시간(루프 전체 길이)까지 안 기다리고, 정해진 시간만 보여준 뒤 다음 노드로
// 넘어가야 해서 따로 고정값을 둠. 여기 없는 노드는 기존처럼 GifDuration으로 실제 재생 시간을 잼
const Map<String, int> _autoAdvanceDurationOverrideMs = {
  'line_029a6_eat': 2000,
  'line_029a6_cry': 3000,
};

// 대화 그래프를 관리하고, 선택지/대사 진행/온도계 상태를 GamePlayScreen에 전달하는 역할
class SceneDialogueController extends ChangeNotifier {
  SceneDialogueController({
    required this.onDialogueEnd,
    required this.onLillianHop,
    required this.onChaeonHop,
    int initialTemperature = 3,
  }) : temperature = initialTemperature;

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

  // 온도계 레벨. KitchenScreen처럼 다른 화면에서 이어받을 때는 initialTemperature로 시작값을 맞춤
  int temperature;
  // 온도 변화 안내 문구
  String? temperatureChangeText;
  Timer? _temperatureChangeTimer;

  // 말풍선 타이핑 효과
  Timer? _typingTimer;
  int typedCharCount = 0;
  static const Duration _typingInterval = Duration(milliseconds: 50);

  // 노드에 진입해도 말풍선을 바로 안 띄우고 대기 중인지. line_001/line_002처럼
  // GIF 재생이 먼저 끝나야 하는 노드에서만 잠깐 false로 바뀜
  bool bubbleRevealed = true;
  Timer? _bubbleRevealTimer;

  // 릴리안 GIF 재생이 끝나길 기다렸다가 자동으로 다음 노드로 넘어가는 중인지.
  // true인 동안은 유저가 탭해도 advanceScene이 아무 것도 안 함
  bool _autoAdvancePending = false;
  Timer? _autoAdvanceTimer;

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
    // 새 대화가 choice 노드로 바로 시작하면 lastLineNode를 안 거치므로, 이전 대화의
    // 마지막 대사가 그대로 남아 선택지 버튼 뒤에 비쳐 보이는 걸 막기 위해 리셋
    lastLineNode = null;
    _enterSceneNode(graph.start);
    _notify();
  }

  // line 노드면 온도 효과 바로 적용하고 타이핑 시작, next 없거나 이상한 노드면 대화 종료
  void _enterSceneNode(String? nodeId) {
    _typingTimer?.cancel();
    _bubbleRevealTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    final graph = sceneDialogue;
    if (nodeId == null || graph == null || !graph.nodes.containsKey(nodeId)) {
      sceneNodeId = null;
      sceneDialogue = null;
      typedCharCount = 0;
      bubbleRevealed = true;
      _autoAdvancePending = false;
      onDialogueEnd();
      return;
    }
    sceneNodeId = nodeId;
    final node = _resolvePlaceholders(graph, nodeId);
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
      // first_bread.json의 line_001/line_002만 GIF 다 재생될 때까지 말풍선을 숨겨둠
      final String? delayGifAsset = graph.dialogueId == _bubbleDelayDialogueId
          ? _bubbleDelayGifByNodeId[nodeId]
          : null;
      // first_meet.json의 line_029a6_eat/line_029a6_cry는 대사 자체가 없고,
      // GIF 다 재생되면 탭 없이 바로 다음 노드로 넘어가야 함
      final String? autoAdvanceGifAsset =
          graph.dialogueId == _autoAdvanceDialogueId
          ? _autoAdvanceGifByNodeId[nodeId]
          : null;
      if (delayGifAsset != null) {
        bubbleRevealed = false;
        typedCharCount = 0;
        _waitForGifThenRevealBubble(delayGifAsset, node);
      } else if (autoAdvanceGifAsset != null) {
        bubbleRevealed = true;
        typedCharCount = 0;
        _autoAdvancePending = true;
        _waitForGifThenAutoAdvance(autoAdvanceGifAsset, node);
      } else {
        bubbleRevealed = true;
        _startTypingEffect(node);
      }
    } else {
      typedCharCount = 0;
      bubbleRevealed = true;
      _autoAdvancePending = false;
    }
  }

  // {{ingredient}} 같은 플레이스홀더가 든 노드면 실제 값으로 치환한 새 노드를 만들어
  // graph.nodes에 덮어써두고 반환. 플레이스홀더가 없으면 원래 노드를 그대로 반환.
  // graph.nodes에 덮어써야 이후 뒤로가기나 다른 화면에서 같은 노드ID로 다시 조회해도
  // 치환된 텍스트가 그대로 보임
  DialogueNode _resolvePlaceholders(DialogueGraph graph, String nodeId) {
    final node = graph.nodes[nodeId]!;
    if (node.type != 'line' ||
        !node.spans.any((s) => s.text.contains('{{'))) {
      return node;
    }

    final String ingredientName = StoryState.resolveIngredientName() ?? '???';
    final resolvedSpans = node.spans
        .map(
          (s) => DialogueSpan(
            text: s.text.replaceAll('{{ingredient}}', ingredientName),
            color: s.color,
            bold: s.bold,
            size: s.size,
          ),
        )
        .toList();

    final resolvedNode = DialogueNode(
      id: node.id,
      type: node.type,
      speaker: node.speaker,
      spans: resolvedSpans,
      temperatureEffect: node.temperatureEffect,
      next: node.next,
      options: node.options,
      animation: node.animation,
    );
    graph.nodes[nodeId] = resolvedNode;
    return resolvedNode;
  }

  // GIF 총 재생 시간을 계산해서 그만큼 기다렸다가 말풍선을 띄우고 타이핑 시작.
  // 그 사이에 다른 노드로 넘어가버렸으면(뒤로가기 등) 그냥 무시함
  void _waitForGifThenRevealBubble(String gifAsset, DialogueNode node) async {
    final int durationMs = await GifDuration.totalMs(gifAsset);
    if (_isDisposed || sceneNodeId != node.id) return;
    _bubbleRevealTimer = Timer(Duration(milliseconds: durationMs), () {
      if (_isDisposed || sceneNodeId != node.id) return;
      bubbleRevealed = true;
      _startTypingEffect(node);
      _notify();
    });
  }

  // GIF 총 재생 시간을 계산해서 그만큼 기다렸다가, 유저 탭 없이 바로 다음 노드로 넘어감.
  // advanceScene()이랑 똑같이 히스토리에 쌓고 다음 노드로 진입하는 것까지 직접 처리함
  void _waitForGifThenAutoAdvance(String gifAsset, DialogueNode node) async {
    final int? overrideMs = _autoAdvanceDurationOverrideMs[node.id];
    final int durationMs = overrideMs ?? await GifDuration.totalMs(gifAsset);
    if (_isDisposed || sceneNodeId != node.id) return;
    _autoAdvanceTimer = Timer(Duration(milliseconds: durationMs), () {
      if (_isDisposed || sceneNodeId != node.id) return;
      _autoAdvancePending = false;
      sceneNodeHistory.add(node.id);
      _enterSceneNode(node.next);
      _notify();
    });
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
    // GIF 재생 중이라 말풍선이 아직 안 떴으면 탭 무시
    if (!bubbleRevealed) return;
    // 릴리안 GIF 재생 끝나면 자동으로 넘어가는 노드는 탭으로 못 넘기게 막음
    if (_autoAdvancePending) return;

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
    // setVars 있으면 전역 저장소에 병합 저장 (나중에 재료 매칭 등에서 참조)
    if (option.setVars != null) {
      StoryState.vars.addAll(option.setVars!);
    }
    _enterSceneNode(option.next);
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _typingTimer?.cancel();
    _bubbleRevealTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _temperatureChangeTimer?.cancel();
    _choiceLockedMessageTimer?.cancel();
    super.dispose();
  }
}
