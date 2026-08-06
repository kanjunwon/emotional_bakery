// lib/features/chapter2/bread_making_scene.dart

// 챕터2: 마법 재료를 골라 빵 반죽에 넣는 미니게임 화면. dough_basic.png를 배경으로
// 가로 꽉 차게 깔고(세로는 하단 기준), 화면 오른쪽에 재료 선택 트레이(bread_choice.png)와
// 그 위에 재료 3개(마법재료/설탕/밀가루)를 띄움

import 'package:flutter/material.dart';
import 'package:emotional_bakery/core/services/story_state.dart';
import 'package:emotional_bakery/core/widgets/shared_ui.dart';

// 튜토리얼 안내 문구. 검은 반투명 배경 위, 재료 3개는 그대로 보이게 띄운 상태로 표시되고,
// 탭하면 닫히고 실제 게임으로 넘어감
const String _tutorialText = '빵을 만들기 위해 재료를 넣어야 합니다.\n모든 재료를 드래그하여 빵에 넣어주세요.';

// 트레이/재료 위치는 다른 화면들과 동일하게 실제 화면(뷰포트) 기준 874x402 좌표계를 씀.
// 배경 캔버스(526)랑 달리 잘려나가는 부분 없이 항상 화면 맨 위/오른쪽 기준으로 고정됨
const double _uiCanvasWidth = 874;
const double _uiCanvasHeight = 402;

// 재료 선택 트레이(bread_choice.png) 크기. 원본(564x1440)이랑 정확히 같은 비율(1:4)이라
// BoxFit.fill로 그려도 안 찌그러짐
const double _trayWidth = 141;
const double _trayHeight = 360;
// 화면 오른쪽 끝에서 트레이 오른쪽 끝까지의 거리
const double _trayRightMargin = 30;

// 트레이 안에 위에서부터 순서대로 놓이는 재료 3개(마법재료/설탕/밀가루) 아이콘 크기.
// 트레이 안에서 가로는 중앙 정렬, 세로는 동일한 간격으로 배치
const double _ingredientSize = 104;

// 재료를 드래그해서 넣는 히트박스(반죽 위치). 재료를 이 영역 안에 놓으면 사라짐
const double _dropZoneLeft = 237;
const double _dropZoneTop = 139;
const double _dropZoneWidth = 300;
const double _dropZoneHeight = 200;

// minigame_success 배너 위치/크기. 구름 치우기 게임(memory_flashback_scene.dart)의
// 성공 연출과 동일한 값을 그대로 씀
const double _successBannerLeft = 158;
const double _successBannerTop = 43;
const double _successBannerWidth = 557;
const double _successBannerHeight = 129;

class BreadMakingScene extends StatefulWidget {
  const BreadMakingScene({super.key, required this.onComplete});

  // 완성된 반죽 화면을 탭하면 호출됨. 주방 화면으로 돌아가서 빵 팝업을 띄우는 건
  // 이 콜백을 받는 쪽(kitchen_screen.dart)의 책임
  final VoidCallback onComplete;

  @override
  State<BreadMakingScene> createState() => _BreadMakingSceneState();
}

class _BreadMakingSceneState extends State<BreadMakingScene> {
  // 게임 화면 진입 시 먼저 튜토리얼을 보여주고, 탭하면 닫힌 뒤 실제 게임(드래그 등)으로 넘어감
  bool _showTutorial = true;
  // 드롭존(반죽) 안에 넣어서 사라진 재료들의 인덱스 (trayIngredientAssets 기준)
  final Set<int> _consumedIngredients = {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        // 트레이/재료 전용 스케일: 다른 화면들이랑 동일한 874x402 뷰포트 좌표계라
        // 화면 맨 위/오른쪽 기준으로 고정되고, 배경이 잘리는 것과 무관하게 위치가 유지됨
        double rW(double px) => (px / _uiCanvasWidth) * w;
        double rH(double px) => (px / _uiCanvasHeight) * h;

        // 트레이를 실제 화면(뷰포트, 402 기준) 세로 가운데 정렬
        final double trayTop = (_uiCanvasHeight - _trayHeight) / 2;
        // 재료 3개가 트레이 안에서 위아래로 동일한 간격을 두고 배치되도록 계산
        // (간격 4개 + 아이콘 3개 = 트레이 세로 길이)
        final double ingredientGap = (_trayHeight - _ingredientSize * 3) / 4;
        // 트레이 안에서 가로로 중앙 정렬했을 때 좌우 여백(대칭이라 오른쪽 기준 계산에도 그대로 씀)
        final double ingredientInset = (_trayWidth - _ingredientSize) / 2;

        final List<String?> trayIngredientAssets = [
          StoryState.resolveIngredientImage(),
          'assets/images/sugar.png',
          'assets/images/flour.png',
        ];
        // 재료를 다 넣었는지: 트레이에 실제로 뜬 재료 개수(보통 3개)만큼 드롭존에 들어갔는지로 판단
        final int totalIngredients = trayIngredientAssets
            .whereType<String>()
            .length;
        final String? completedDoughAsset =
            StoryState.resolveCompletedDoughImage();
        final bool isDoughComplete =
            totalIngredients > 0 &&
            _consumedIngredients.length >= totalIngredients &&
            completedDoughAsset != null;

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 배경: 재료를 다 넣기 전엔 dough_basic, 다 넣으면 선택한 재료에 맞는 완성 반죽으로 교체.
              // memory_flashback_scene.dart(park_kid 등)와 동일하게 BoxFit.cover로 화면을
              // 항상 꽉 채워서, 창 비율이 달라져도 검은 여백이 안 생기고 유동적으로 꽉 채움.
              // 탭하면 주방 화면으로 돌아감(빵 팝업은 돌아간 쪽에서 띄움)
              if (isDoughComplete)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onComplete,
                    child: Stack(
                      children: [
                        Image.asset(
                          completedDoughAsset,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.5),
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        // 재료를 다 넣었다는 성공 배너. 구름 게임(memory_flashback_scene.dart)의
                        // minigame_success 연출과 동일한 자산/위치를 그대로 씀
                        Positioned(
                          left: rW(_successBannerLeft),
                          top: rH(_successBannerTop),
                          width: rW(_successBannerWidth),
                          height: rH(_successBannerHeight),
                          child: Image.asset(
                            'assets/images/minigame_success.png',
                            width: rW(_successBannerWidth),
                            height: rH(_successBannerHeight),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/dough_basic.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),

              // 재료를 다 넣으면 트레이/드롭존은 더 이상 필요 없어서 숨김
              if (!isDoughComplete) ...[
                // 재료 선택 트레이
                Positioned(
                  right: rW(_trayRightMargin),
                  top: rH(trayTop),
                  width: rW(_trayWidth),
                  height: rH(_trayHeight),
                  child: Image.asset(
                    'assets/images/bread_choice.png',
                    fit: BoxFit.fill,
                  ),
                ),

                // 튜토리얼 중에는 배경/트레이를 검은 반투명(50%)으로 덮음. 재료 3개는 이
                // 레이어보다 위(아래쪽)에 다시 그려서 어둡게 덮이지 않고 그대로 보이게 함
                if (_showTutorial)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: Color(0x80000000)),
                    ),
                  ),

                // 반죽(드롭존): 재료를 여기 안에 놓으면 사라짐. 눈에는 안 보이고 히트박스만 있음
                Positioned(
                  left: rW(_dropZoneLeft),
                  top: rH(_dropZoneTop),
                  width: rW(_dropZoneWidth),
                  height: rH(_dropZoneHeight),
                  child: DragTarget<int>(
                    onAcceptWithDetails: (details) {
                      setState(() => _consumedIngredients.add(details.data));
                    },
                    builder: (context, candidateData, rejectedData) {
                      return const SizedBox.expand();
                    },
                  ),
                ),
              ],

              // 트레이 위 재료 3개 (마법재료 -> 설탕 -> 밀가루 순으로 위에서 아래로).
              // 튜토리얼 중에도 어두워지지 않고 그대로 보이도록 위 딤 레이어보다 나중에 그림.
              // 드래그해서 반죽 드롭존 안에 놓으면 사라짐(_consumedIngredients)
              for (int i = 0; i < trayIngredientAssets.length; i++)
                if (trayIngredientAssets[i] != null &&
                    !_consumedIngredients.contains(i))
                  Positioned(
                    right: rW(_trayRightMargin + ingredientInset),
                    top: rH(
                      trayTop + ingredientGap * (i + 1) + _ingredientSize * i,
                    ),
                    width: rW(_ingredientSize),
                    height: rH(_ingredientSize),
                    child: Draggable<int>(
                      data: i,
                      feedback: Image.asset(
                        trayIngredientAssets[i]!,
                        width: rW(_ingredientSize),
                        height: rH(_ingredientSize),
                        fit: BoxFit.contain,
                      ),
                      childWhenDragging: const SizedBox.shrink(),
                      child: Image.asset(
                        trayIngredientAssets[i]!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

              // 튜토리얼 안내 문구. 탭하면 닫히고 실제 게임으로 넘어감
              if (_showTutorial)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _showTutorial = false),
                    child: Stack(
                      children: [
                        Positioned(
                          left: rW(230),
                          top: rH(60),
                          child: DialogueBoxFrame(
                            textWidget: Text(
                              _tutorialText,
                              textAlign: TextAlign.center,
                              style: dialogueTextStyle(rW),
                            ),
                            rW: rW,
                            rH: rH,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
