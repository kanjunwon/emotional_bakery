// lib/features/chapter3/diary_puzzle_scene.dart

// 챕터3 두 번째 미니게임: 일기장 사진 조각 6개를 오른쪽 페이지 트레이에서 왼쪽 페이지
// 사진 액자의 정답 위치로 드래그해서 맞추는 퍼즐. bread_making_scene.dart(챕터2)의
// LayoutBuilder + 874x402 좌표계 구조는 그대로 따르지만, 여기는 조각마다 정답 위치가
// 따로 있고 자석처럼 스냅되는 방식이라 Draggable/DragTarget 대신 GestureDetector로
// 조각 위치를 직접 추적함

import 'dart:async';
import 'package:flutter/material.dart';

// 화면(뷰포트) 기준 874x402 좌표계. bread_making_scene.dart랑 동일한 기준
const double _uiCanvasWidth = 874;
const double _uiCanvasHeight = 402;

// 조각 6개 공통 크기 + 그리드 간격. diary_puzzle_bg.png(원본 3496x2620) 픽셀을 직접
// 분석해서 나온 값: 사진 액자 영역이 원본 기준 (715,791)~(1660,1422)(945x631px),
// BoxFit.cover로 캔버스에 그릴 때 배율 0.25 + 세로 506px 크롭이 적용되니까 캔버스
// 좌표로는 (179,71)~(415,229)(236x158). 이걸 2열x3행 그리드로 나눠서 계산한 값
// _pieceWidth: 조각 하나의 가로 크기. 숫자를 늘리면 조각 6개가 전부 옆으로 넓어짐
// (액자/트레이에도 같이 쓰여서 둘 다 커짐). 너무 크게 잡으면 조각끼리 겹쳐 보임
const double _pieceWidth = 115;
// _pieceHeight: 조각 하나의 세로 크기. 숫자를 늘리면 조각 6개가 전부 위아래로 두꺼워짐
const double _pieceHeight = 49;
// _frameColumnGap: 액자 안에서 조각과 조각 사이 가로 간격(왼쪽 열 <-> 오른쪽 열).
// 숫자를 늘리면 두 열 사이가 벌어짐
const double _frameColumnGap = 6;
// _frameRowGap: 액자 안에서 조각과 조각 사이 세로 간격(위 행 <-> 아래 행).
// 숫자를 늘리면 행끼리 벌어짐
const double _frameRowGap = 6;

// _frameGridLeft/_frameGridTop: 왼쪽 페이지 사진 액자 영역의 왼쪽 위 모서리 좌표
// (정답 위치 그리드 전체의 기준점). Left를 늘리면 액자 그리드 6칸 전체가 오른쪽으로,
// Top을 늘리면 전체가 아래로 같이 이동함(6칸이 통째로 움직임, 한 칸만 따로는 안 움직임)
const double _frameGridLeft = 179;
const double _frameGridTop = 71;
// 액자 전체 크기(완성 이미지를 액자 안에 끼워 넣을 때 씀) = 그리드 2열x3행 합계.
// _pieceWidth/Height나 gap을 바꾸면 이 값도 자동으로 같이 바뀜
const double _frameAreaWidth = _pieceWidth * 2 + _frameColumnGap;
const double _frameAreaHeight = _pieceHeight * 3 + _frameRowGap * 2;

// _trayGridLeft/_trayGridTop: 오른쪽 페이지 트레이 그리드(조각이 처음 놓여있는 위치)의
// 왼쪽 위 모서리 좌표. diary_puzzle_bg.png의 오른쪽 페이지는 실제로는 빈 여백이라
// (원본 기준 x:1710~2844, y:564~2044, 캔버스로는 x:427.5~711, y:14.5~384.5) 정답
// 그리드랑 같은 크기의 그리드를 그 안에 가운데 정렬해서 배치함. Left를 늘리면 트레이
// 6칸 전체가 오른쪽으로, Top을 늘리면 전체가 아래로 같이 이동함(액자와 동일한 규칙)
const double _trayGridLeft = 451;
const double _trayGridTop = 120;
const double _trayColumnGap = _frameColumnGap;
const double _trayRowGap = _frameRowGap;

// 조각 6개의 정답 위치(왼쪽 액자, 2열x3행 그리드). index는 diary_puzzle_piece_1~6에
// 순서대로 대응(0-based, 왼쪽 위부터 가로로 채워나감).
// 예: _pieceTargetPositions[0]은 1번 조각(액자 1행 1열, 맨 왼쪽 위)이 들어가야 할 좌표.
// 지금은 전부 _frameGridLeft/Top + 그리드 칸 수로 계산되는 수식이라, 6칸을 통째로
// 옮기려면 위쪽 _frameGridLeft/Top을 바꾸면 됨. 특정 조각 하나만 따로 옮기고 싶으면
// 해당 줄의 Offset(...) 계산식을 원하는 좌표 숫자로 직접 바꿔주면 됨(그 줄만 그리드
// 계산에서 빠지고 고정값을 쓰게 됨)
const List<Offset> _pieceTargetPositions = [
  Offset(_frameGridLeft, _frameGridTop), // piece_1: 1행 1열(맨 왼쪽 위)
  Offset(
    _frameGridLeft + _pieceWidth + _frameColumnGap,
    _frameGridTop,
  ), // piece_2: 1행 2열(맨 오른쪽 위)
  Offset(
    _frameGridLeft,
    _frameGridTop + _pieceHeight + _frameRowGap,
  ), // piece_3: 2행 1열(왼쪽 가운데)
  Offset(
    _frameGridLeft + _pieceWidth + _frameColumnGap,
    _frameGridTop + _pieceHeight + _frameRowGap,
  ), // piece_4: 2행 2열(오른쪽 가운데)
  Offset(
    _frameGridLeft,
    _frameGridTop + (_pieceHeight + _frameRowGap) * 2,
  ), // piece_5: 3행 1열(왼쪽 아래)
  Offset(
    _frameGridLeft + _pieceWidth + _frameColumnGap,
    _frameGridTop + (_pieceHeight + _frameRowGap) * 2,
  ), // piece_6: 3행 2열(오른쪽 아래, 맨 마지막 조각)
];

// 조각 6개의 시작 위치(오른쪽 트레이, 동일한 2열x3행 그리드 패턴). 위 정답 위치
// 리스트랑 완전히 같은 구조라, 특정 조각의 시작 위치만 따로 옮기고 싶을 때도
// 해당 줄의 Offset(...)을 직접 바꿔주면 됨
const List<Offset> _pieceStartPositions = [
  Offset(_trayGridLeft, _trayGridTop),
  Offset(_trayGridLeft + _pieceWidth + _trayColumnGap, _trayGridTop),
  Offset(_trayGridLeft, _trayGridTop + _pieceHeight + _trayRowGap),
  Offset(
    _trayGridLeft + _pieceWidth + _trayColumnGap,
    _trayGridTop + _pieceHeight + _trayRowGap,
  ),
  Offset(_trayGridLeft, _trayGridTop + (_pieceHeight + _trayRowGap) * 2),
  Offset(
    _trayGridLeft + _pieceWidth + _trayColumnGap,
    _trayGridTop + (_pieceHeight + _trayRowGap) * 2,
  ),
];

const List<String> _pieceAssets = [
  'assets/images/diary_puzzle_piece_1.png',
  'assets/images/diary_puzzle_piece_2.png',
  'assets/images/diary_puzzle_piece_3.png',
  'assets/images/diary_puzzle_piece_4.png',
  'assets/images/diary_puzzle_piece_5.png',
  'assets/images/diary_puzzle_piece_6.png',
];

// 조각을 드롭했을 때 정답 위치로 스냅되는 허용 범위. 조각 크기(_pieceWidth) 대비 비율.
// 디자이너랑 실제 비율 보고 조정 예정
// 숫자를 늘리면(예: 0.5) 정답 위치에서 좀 멀리 놓아도 스냅되어서 게임이 쉬워지고,
// 줄이면(예: 0.15) 거의 정확한 자리에 놓아야만 스냅돼서 게임이 어려워짐. 0이면
// 정답 위치에 픽셀 단위로 정확히 겹쳐야만 스냅됨
const double _pieceSnapToleranceRatio = 0.35;

// minigame_success 배너 위치/크기. 챕터1/2 미니게임 성공 연출과 동일한 값을 그대로 씀
const double _successBannerLeft = 158;
const double _successBannerTop = 43;
const double _successBannerWidth = 557;
const double _successBannerHeight = 129;

// 6조각 다 스냅되고 나서, 액자가 자연스럽게 채워진 상태로 유지하는 시간
const Duration _pieceCompletedHoldDuration = Duration(seconds: 1);
// SUCCESS 배너 노출 유지 시간. 이 값을 조정하면 SUCCESS 배너가 뜨고 나서 widget.onComplete()가
// 호출되어 다음 화면(kitchen_screen.dart의 결과 이미지 -> 암전 -> chapter3_after_eat.json)으로
// 넘어가기까지의 대기 시간이 바뀜
const Duration _successHoldDuration = Duration(seconds: 3);
// SUCCESS 단계에서 diary_puzzle_completed.png를 확대해서 보여줄 배율
const double _successZoomScale = 1.3;

class DiaryPuzzleScene extends StatefulWidget {
  const DiaryPuzzleScene({super.key, required this.onComplete});

  // 조각 6개를 다 맞추고 SUCCESS 연출까지 끝나면 호출됨. 다음 화면 전환은 호출부 책임
  final VoidCallback onComplete;

  @override
  State<DiaryPuzzleScene> createState() => _DiaryPuzzleSceneState();
}

class _DiaryPuzzleSceneState extends State<DiaryPuzzleScene> {
  // 조각 6개의 현재 위치(캔버스 874x402 좌표계, 왼쪽 위 모서리 기준). 처음엔 오른쪽
  // 트레이 그리드(_pieceStartPositions)에서 시작
  late final List<Offset> _piecePositions = List.of(_pieceStartPositions);
  // 정답 위치에 스냅되어 고정된 조각 인덱스. 스냅되면 더 이상 드래그 안 됨
  final Set<int> _snappedPieces = {};
  // 6개 다 스냅된 뒤, 액자가 자연스럽게 채워진 상태로 잠깐 유지하는 단계
  bool _isPieceCompletedHoldActive = false;
  // 그 다음, 화면을 확대해서 SUCCESS 배너를 보여주는 단계
  bool _isSuccessActive = false;
  Timer? _completedHoldTimer;
  Timer? _successTimer;

  @override
  void dispose() {
    _completedHoldTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }

  // 조각 하나를 드래그하다 손을 뗐을 때: 정답 위치와의 거리가 허용 범위 안이면 스냅해서
  // 고정. 범위를 벗어나면 트레이로 되돌리지 않고 놓은 자리에 그대로 둠(다시 시도할 수
  // 있게, 갑자기 튕겨 돌아가는 것보다 자연스러워서 이렇게 함)
  void _handlePieceDragEnd(int index) {
    final Offset target = _pieceTargetPositions[index];
    final double distance = (_piecePositions[index] - target).distance;
    final double tolerance = _pieceWidth * _pieceSnapToleranceRatio;
    if (distance > tolerance) return;
    setState(() {
      _piecePositions[index] = target;
      _snappedPieces.add(index);
    });
    if (_snappedPieces.length >= _pieceAssets.length) {
      _startCompletionSequence();
    }
  }

  // 6조각 다 스냅되면 시작: 완성된 액자 상태 잠깐 유지 -> 화면 확대 + SUCCESS 배너 ->
  // 적당한 시간 뒤 onComplete 자동 호출
  void _startCompletionSequence() {
    setState(() => _isPieceCompletedHoldActive = true);
    _completedHoldTimer = Timer(_pieceCompletedHoldDuration, () {
      if (!mounted) return;
      setState(() {
        _isPieceCompletedHoldActive = false;
        _isSuccessActive = true;
      });
      _successTimer = Timer(_successHoldDuration, () {
        if (mounted) widget.onComplete();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        double rW(double px) => (px / _uiCanvasWidth) * w;
        double rH(double px) => (px / _uiCanvasHeight) * h;
        // 화면 픽셀 단위 드래그 델타를 캔버스(874x402) 좌표 델타로 되돌리는 배율
        final double scaleX = w / _uiCanvasWidth;
        final double scaleY = h / _uiCanvasHeight;

        final bool isPuzzleComplete =
            _isPieceCompletedHoldActive || _isSuccessActive;

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 배경: SUCCESS 단계(_isSuccessActive) 전까지는 diary_puzzle_bg.png(일기장
              // 두 페이지)를 계속 보여줌. bread_making_scene.dart(챕터2)랑 동일하게
              // BoxFit.cover로 화면을 항상 꽉 채움. SUCCESS 단계에서만 diary_puzzle_completed.png
              // 전체화면으로 바뀌면서 Transform.scale로 확대됨
              if (_isSuccessActive)
                Positioned.fill(
                  child: Transform.scale(
                    scale: _successZoomScale,
                    child: Image.asset(
                      'assets/images/diary_puzzle_completed.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/diary_puzzle_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),

              // 6조각 다 스냅된 직후(_isPieceCompletedHoldActive) 잠깐: 낱개 조각 대신
              // diary_puzzle_completed.png를 액자 영역(_frameGridLeft/Top,
              // _frameAreaWidth/Height) 크기에 맞춰 끼워 넣어서, 액자 안이 자연스럽게
              // 채워진 것처럼 보이게 함. 배경은 diary_puzzle_bg.png 그대로 유지(두 페이지 다 보임)
              if (_isPieceCompletedHoldActive)
                Positioned(
                  left: rW(_frameGridLeft),
                  top: rH(_frameGridTop),
                  width: rW(_frameAreaWidth),
                  height: rH(_frameAreaHeight),
                  child: Image.asset(
                    'assets/images/diary_puzzle_completed.png',
                    fit: BoxFit.cover,
                  ),
                ),

              // 조각 6개. 완성 이미지로 교체되기 전까지만 그리고, 스냅된 조각은 정답
              // 위치에 고정된 채 계속 보임(하나씩 맞춰지는 게 자연스럽게 보이도록)
              if (!isPuzzleComplete)
                for (int i = 0; i < _pieceAssets.length; i++)
                  Positioned(
                    left: rW(_piecePositions[i].dx),
                    top: rH(_piecePositions[i].dy),
                    width: rW(_pieceWidth),
                    height: rH(_pieceHeight),
                    child: GestureDetector(
                      onPanUpdate: _snappedPieces.contains(i)
                          ? null
                          : (details) {
                              setState(() {
                                _piecePositions[i] += Offset(
                                  details.delta.dx / scaleX,
                                  details.delta.dy / scaleY,
                                );
                              });
                            },
                      onPanEnd: _snappedPieces.contains(i)
                          ? null
                          : (_) => _handlePieceDragEnd(i),
                      child: Image.asset(_pieceAssets[i], fit: BoxFit.contain),
                    ),
                  ),

              // SUCCESS 배너. 챕터1/2 미니게임 성공 연출과 동일한 자산/위치
              if (_isSuccessActive)
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
        );
      },
    );
  }
}
