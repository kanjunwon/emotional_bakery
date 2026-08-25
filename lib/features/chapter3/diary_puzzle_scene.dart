// lib/features/chapter3/diary_puzzle_scene.dart

// 챕터3 두 번째 미니게임: 일기장 사진 조각 6개를 오른쪽 페이지 트레이에서 왼쪽 페이지
// 사진 액자의 정답 위치로 드래그해서 맞추는 퍼즐. bread_making_scene.dart(챕터2)의
// LayoutBuilder + 874x402 좌표계 구조는 그대로 따르지만, 여기는 조각마다 정답 위치가
// 따로 있고 자석처럼 스냅되는 방식이라 Draggable/DragTarget 대신 GestureDetector로
// 조각 위치를 직접 추적함

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// 화면(뷰포트) 기준 874x402 좌표계. bread_making_scene.dart랑 동일한 기준
const double _uiCanvasWidth = 874;
const double _uiCanvasHeight = 402;

// 화면 비율이 874:402가 아닌 기기에서 diary_puzzle_bg.png가 BoxFit.cover로 맞춰지면서
double _bgCoverScaleX(double w, double h) {
  final double coverScale = math.max(w / _uiCanvasWidth, h / 655);
  return coverScale * (_uiCanvasWidth / w);
}

double _bgCoverScaleY(double w, double h) {
  final double coverScale = math.max(w / _uiCanvasWidth, h / 655);
  return coverScale * (_uiCanvasHeight / h);
}

double _bgAnchorX(double refCanvasX, double scaleX) =>
    scaleX * (refCanvasX - _uiCanvasWidth / 2) + _uiCanvasWidth / 2;
double _bgAnchorY(double refCanvasY, double scaleY) =>
    scaleY * (refCanvasY - _uiCanvasHeight / 2) + _uiCanvasHeight / 2;
double _bgSize(double refCanvasSize, double scale) => scale * refCanvasSize;

// 조각 6개 정답 위치/시작 위치 관련 레퍼런스 값. 캔버스 874x402 좌표계 기준, 실제 화면
const double _pieceWidthRef = 77;
const double _pieceHeightRef = 77;
// _frameColumnGapRef: 액자 안에서 조각과 조각 사이 가로 간격(열과 열 사이, 레퍼런스).
// 숫자를 늘리면 열끼리 벌어짐
const double _frameColumnGapRef = 1;
// _frameRowGapRef: 액자 안에서 조각과 조각 사이 세로 간격(행과 행 사이, 레퍼런스).
// 숫자를 늘리면 행끼리 벌어짐
const double _frameRowGapRef = 1;

// 액자 안에서 조각 6개를 3열x2행 그리드로 배치할 때, 왼쪽 위 모서리 기준으로
const double _frameGridLeftRef = 181;
const double _frameGridTopRef = 73.5;
const double _topRowDropForVisualGapRef = 0.5;

// 조각 6개의 정답 위치 레퍼런스
const List<Offset> _pieceTargetPositionsRef = [
  Offset(
    _frameGridLeftRef,
    _frameGridTopRef + _topRowDropForVisualGapRef,
  ), // piece_1: 1행 1열(맨 왼쪽 위)
  Offset(
    _frameGridLeftRef + _pieceWidthRef + _frameColumnGapRef,
    _frameGridTopRef + _pieceHeightRef + _frameRowGapRef,
  ), // piece_2: 2행 2열(가운데 아래)
  Offset(
    _frameGridLeftRef,
    _frameGridTopRef + _pieceHeightRef + _frameRowGapRef,
  ), // piece_3: 2행 1열(왼쪽 아래)
  Offset(
    _frameGridLeftRef + (_pieceWidthRef + _frameColumnGapRef) * 2,
    _frameGridTopRef + _pieceHeightRef + _frameRowGapRef,
  ), // piece_4: 2행 3열(오른쪽 아래, 맨 마지막 조각)
  Offset(
    _frameGridLeftRef + (_pieceWidthRef + _frameColumnGapRef) * 2,
    _frameGridTopRef + _topRowDropForVisualGapRef,
  ), // piece_5: 1행 3열(맨 오른쪽 위)
  Offset(
    _frameGridLeftRef + _pieceWidthRef + _frameColumnGapRef,
    _frameGridTopRef + _topRowDropForVisualGapRef,
  ), // piece_6: 1행 2열(가운데 위)
];

// 조각 6개 시작 위치(트레이) 레퍼런스. 캔버스 874x402 좌표계 기준, 실제 화면
const List<Offset> _pieceStartPositionsRef = [
  Offset(471, 55.5), // piece_1
  Offset(583, 56.5), // piece_2
  Offset(471, 270.5), // piece_3
  Offset(471, 162.5), // piece_4
  Offset(583, 162.5), // piece_5
  Offset(583, 269.5), // piece_6
];

const List<String> _pieceAssets = [
  'assets/images/diary_puzzle_piece_1.png',
  'assets/images/diary_puzzle_piece_2.png',
  'assets/images/diary_puzzle_piece_3.png',
  'assets/images/diary_puzzle_piece_4.png',
  'assets/images/diary_puzzle_piece_5.png',
  'assets/images/diary_puzzle_piece_6.png',
];

// 스냅 허용 범위 비율. 조각 가로 길이 대비 몇 배까지 떨어져 있어도 스냅되는지
const double _pieceSnapToleranceRatio = 0.35;

// minigame_success 배너 위치/크기. 챕터1/2 미니게임 성공 연출과 동일한 값을 그대로 씀
const double _successBannerLeft = 158;
const double _successBannerTop = 43;
const double _successBannerWidth = 557;
const double _successBannerHeight = 129;

// diary_puzzle_completed_bg.png로 전환된 채, diary_puzzle_completed.png로 확대되기 전까지
const Duration _completedBgHoldDuration = Duration(seconds: 1);
// diary_puzzle_completed.png로 확대된 채, SUCCESS 배너가 뜨기 전까지
const Duration _zoomHoldDuration = Duration(milliseconds: 800);
// SUCCESS 배너가 뜬 채, onComplete() 호출 전까지
const Duration _successHoldDuration = Duration(milliseconds: 1800);

class DiaryPuzzleScene extends StatefulWidget {
  const DiaryPuzzleScene({super.key, required this.onComplete});

  // 조각 6개를 다 맞추고 SUCCESS 연출까지 끝나면 호출됨. 다음 화면 전환은 호출부 책임
  final VoidCallback onComplete;

  @override
  State<DiaryPuzzleScene> createState() => _DiaryPuzzleSceneState();
}

class _DiaryPuzzleSceneState extends State<DiaryPuzzleScene> {
  // 조각 6개 현재 위치. 캔버스 874x402 좌표계 기준, 실제 화면
  List<Offset> _piecePositions = [];
  bool _piecePositionsInitialized = false;
  List<Offset> _pieceTargetPositions = List.of(_pieceTargetPositionsRef);
  // 스냅 허용 범위(픽셀 단위). _pieceWidthRef * _pieceSnapToleranceRatio로 계산됨.
  double _pieceSnapTolerance = _pieceWidthRef * _pieceSnapToleranceRatio;
  // 정답 위치에 스냅되어 고정된 조각 인덱스. 스냅되면 더 이상 드래그 안 됨
  final Set<int> _snappedPieces = {};
  // 조각 6개를 다 맞춰서 SUCCESS 연출이 끝나기 전까지는 true. 그 뒤로는 false
  bool _isCompletedBgActive = false;
  bool _isZoomedActive = false;
  bool _isSuccessActive = false;
  Timer? _completedBgTimer;
  Timer? _zoomTimer;
  Timer? _successTimer;
  bool _imagesPrecached = false;

  // 조각 6개를 다 맞추고 SUCCESS 연출까지 끝나면 호출됨. 다음 화면 전환은 호출부 책임
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      const List<String> assetsToPrecache = [
        'assets/images/diary_puzzle_bg.png',
        'assets/images/diary_puzzle_completed_bg.png',
        'assets/images/diary_puzzle_completed.png',
        'assets/images/minigame_success.png',
        ..._pieceAssets,
      ];
      for (final asset in assetsToPrecache) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _completedBgTimer?.cancel();
    _zoomTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }

  // 조각 드래그가 끝났을 때 호출됨. 스냅 허용 범위 안이면 정답 위치로 스냅하고, 그 뒤로는 드래그 안 됨
  void _handlePieceDragEnd(int index) {
    final Offset target = _pieceTargetPositions[index];
    final double distance = (_piecePositions[index] - target).distance;
    if (distance > _pieceSnapTolerance) return;
    setState(() {
      _piecePositions[index] = target;
      _snappedPieces.add(index);
    });
    if (_snappedPieces.length >= _pieceAssets.length) {
      _startCompletionSequence();
    }
  }

  // 조각 6개를 다 맞추면 호출됨. 배경/조각/배너 순서대로 전환되는 연출을 시작함
  void _startCompletionSequence() {
    setState(() => _isCompletedBgActive = true);
    _completedBgTimer = Timer(_completedBgHoldDuration, () {
      if (!mounted) return;
      setState(() {
        _isCompletedBgActive = false;
        _isZoomedActive = true;
      });
      _zoomTimer = Timer(_zoomHoldDuration, () {
        if (!mounted) return;
        setState(() {
          _isZoomedActive = false;
          _isSuccessActive = true;
        });
        _successTimer = Timer(_successHoldDuration, () {
          if (mounted) widget.onComplete();
        });
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

        // 배경/조각/배너 위치 계산에 필요한 값들을 화면 비율에 맞게 다시 계산
        final double bgScaleX = _bgCoverScaleX(w, h);
        final double bgScaleY = _bgCoverScaleY(w, h);
        final double pieceWidth = _bgSize(_pieceWidthRef, bgScaleX);
        final double pieceHeight = _bgSize(_pieceHeightRef, bgScaleY);
        final double frameColumnGap = _bgSize(_frameColumnGapRef, bgScaleX);
        final double frameRowGap = _bgSize(_frameRowGapRef, bgScaleY);
        final double frameGridLeft = _bgAnchorX(_frameGridLeftRef, bgScaleX);
        final double frameGridTop = _bgAnchorY(_frameGridTopRef, bgScaleY);
        final double topRowDrop = _bgSize(_topRowDropForVisualGapRef, bgScaleY);

        // 조각 6개 정답 위치를 화면 비율에 맞게 다시 계산. 최초 1회만 _pieceTargetPositions를 채움
        _pieceTargetPositions = [
          Offset(frameGridLeft, frameGridTop + topRowDrop), // piece_1
          Offset(
            frameGridLeft + pieceWidth + frameColumnGap,
            frameGridTop + pieceHeight + frameRowGap,
          ), // piece_2
          Offset(
            frameGridLeft,
            frameGridTop + pieceHeight + frameRowGap,
          ), // piece_3
          Offset(
            frameGridLeft + (pieceWidth + frameColumnGap) * 2,
            frameGridTop + pieceHeight + frameRowGap,
          ), // piece_4
          Offset(
            frameGridLeft + (pieceWidth + frameColumnGap) * 2,
            frameGridTop + topRowDrop,
          ), // piece_5
          Offset(
            frameGridLeft + pieceWidth + frameColumnGap,
            frameGridTop + topRowDrop,
          ), // piece_6
        ];

        // 스냅 허용 범위도 실제 조각 가로 크기 기준으로 다시 계산
        _pieceSnapTolerance = pieceWidth * _pieceSnapToleranceRatio;

        // LayoutBuilder가 실제 w/h를 알려주는 첫 build()에서 _pieceStartPositionsRef를 화면 비율에 맞게 변환해 한 번만 채워짐(그 전엔 빈 리스트)
        if (!_piecePositionsInitialized) {
          _piecePositionsInitialized = true;
          _piecePositions = [
            for (final ref in _pieceStartPositionsRef)
              Offset(
                _bgAnchorX(ref.dx, bgScaleX),
                _bgAnchorY(ref.dy, bgScaleY),
              ),
          ];
        }

        // 조각 6개를 다 맞추고 SUCCESS 연출까지 끝나면 호출됨. 다음 화면 전환은 호출부 책임
        for (final index in _snappedPieces) {
          _piecePositions[index] = _pieceTargetPositions[index];
        }

        final bool isPuzzleComplete =
            _isCompletedBgActive || _isZoomedActive || _isSuccessActive;

        // 배경 이미지 경로/BoxFit. _isZoomedActive/_isSuccessActive가 켜지면 diary_puzzle_completed.png로 바뀌고, 그 전까지는 diary_puzzle_bg.png 또는 diary_puzzle_completed_bg.png
        final String backgroundAsset = (_isZoomedActive || _isSuccessActive)
            ? 'assets/images/diary_puzzle_completed.png'
            : _isCompletedBgActive
            ? 'assets/images/diary_puzzle_completed_bg.png'
            : 'assets/images/diary_puzzle_bg.png';
        final BoxFit backgroundFit = (_isZoomedActive || _isSuccessActive)
            ? BoxFit.fitWidth
            : BoxFit.cover;

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 배경 이미지. _isZoomedActive/_isSuccessActive가 켜지면 diary_puzzle_completed.png로 바뀌고, 그 전까지는 diary_puzzle_bg.png 또는 diary_puzzle_completed_bg.png
              Positioned.fill(
                child: Image.asset(
                  backgroundAsset,
                  fit: backgroundFit,
                  gaplessPlayback: true,
                ),
              ),

              // 조각 6개. _isCompletedBgActive/_isZoomedActive/_isSuccessActive가 켜지면 배경/조각/배너 순서대로 전환되는 연출이 진행되므로, 그 전까지는 조각이 화면에 보임
              if (!isPuzzleComplete)
                for (int i = 0; i < _pieceAssets.length; i++)
                  Positioned(
                    left: rW(_piecePositions[i].dx),
                    top: rH(_piecePositions[i].dy),
                    width: rW(pieceWidth),
                    height: rH(pieceHeight),
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
