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

// diary_puzzle_bg.png(원본 비율 874x655)는 실제 화면(w x h)에 항상 BoxFit.cover로
// 그려지는데, 화면이 원본보다 상대적으로 "넓으면"(가로세로 비율 w/h > 874/655≈1.334,
// 대부분의 landscape 화면) 가로 기준으로 꽉 채우고 위아래를 잘라내고, 반대로 화면이
// 원본보다 상대적으로 "좁으면"(w/h < 1.334, 예: 데스크톱에서 창을 세로로 길게 늘렸을 때)
// 세로 기준으로 꽉 채우고 좌우를 잘라낸다. 이때 실제로 잘리는 비율은 화면의 실제
// 가로세로 비율에 따라 달라지므로, 디자이너가 실측해서 준 좌표(874x655 기준)를
// 캔버스(874x402) 좌표로 바꾸는 계산도 화면마다 달라야 정확하다. 가로만 고정, 세로만
// 보정하는 식(예: "y - 126.5"만 적용)으로는 화면이 위 두 경우를 오갈 때(예: 창 크기를
// 자유롭게 조절하는 데스크톱) 조각들이 서로 겹치거나 액자를 벗어나 보이게 됨.
// 그래서 가로/세로 둘 다 build()에서 실제 w/h를 가지고 매번 다시 계산함:
// - _bgCoverScaleX/Y(w,h): 각 축이 화면 비율에 따라 얼마나 늘어나거나 잘리는지 나타내는
//   배율. 화면 비율이 정확히 874:402(≈2.17:1)일 때는 두 값 다 1이 되고, 그때는 아래
//   "레퍼런스 캔버스 값"들이 그대로 정답이 됨
// - _bgAnchorX/Y: 액자 왼쪽 위 모서리 같은 "절대 위치" 값을 변환할 때 씀
//   (공식: 배율 * (레퍼런스값 - 캔버스중앙) + 캔버스중앙)
// - _bgSize: 조각 가로/세로·줄 간격처럼 "크기·간격" 값을 변환할 때 씀
//   (공식: 배율 * 레퍼런스값). x/y 어느 축이든 그 축의 배율을 넣어 재사용
// 아래 "...Ref" 이름이 붙은 상수들은 전부 "화면 비율이 정확히 874:402일 때"를 기준으로
// 잡아둔 레퍼런스 값이고, 실제 렌더링 직전에 build()에서 다시 계산됨
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

// 조각 6개 공통 크기 + 그리드 간격/위치 레퍼런스 값(화면 비율 874:402 기준).
// _pieceWidthRef: 조각 하나의 가로 크기(레퍼런스). 숫자를 늘리면 조각 6개가 전부
// 옆으로 넓어짐(액자/트레이에도 같이 쓰여서 둘 다 커짐). 너무 크게 잡으면 조각끼리
// 겹쳐 보임. 77x77 = 원본 diary_puzzle_piece_*.png(308x308, 304짜리는 308x304)를
// 정확히 1/4로 축소한 값. 조각 이미지는 BoxFit.contain으로 그려지므로 이 박스를
// 정사각형으로 맞추면 308x308 원본(piece 1/5/6)은 77x77로, 308x304 원본(piece
// 2/3/4)은 비율 유지로 자동 77x76으로 그려짐(박스 높이=77이지만 이미지 자체는 76으로
// 렌더링, 위아래 0.5씩 여백). 화면 비율이 874:402가 아니면 build()에서 가로/세로
// 각각 다른 배율로 다시 스케일되므로 실제 렌더링 박스가 정사각형이 아닐 수 있음(배경
// diary_puzzle_bg.png 자체도 같은 방식으로 뒤틀리기 때문에, 배경과 일관되게 맞추려면
// 오히려 이렇게 같이 뒤틀리는 게 맞음)
const double _pieceWidthRef = 77;
const double _pieceHeightRef = 77;
// _frameColumnGapRef: 액자 안에서 조각과 조각 사이 가로 간격(열과 열 사이, 레퍼런스).
// 숫자를 늘리면 열끼리 벌어짐
const double _frameColumnGapRef = 1;
// _frameRowGapRef: 액자 안에서 조각과 조각 사이 세로 간격(행과 행 사이, 레퍼런스).
// 숫자를 늘리면 행끼리 벌어짐
const double _frameRowGapRef = 1;

// _frameGridLeftRef/_frameGridTopRef: 왼쪽 페이지 사진 액자 영역의 왼쪽 위 모서리
// 좌표 레퍼런스(정답 위치 그리드 전체의 기준점, 3열x2행). 디자이너 실측 좌표(874x655
// 기준) (180,200)을 화면 비율 874:402 기준 캔버스 좌표로 변환한 값(200 - 126.5 =
// 73.5, x는 그대로 180). build()에서 _bgAnchorX/Y로 실제 화면 비율에 맞게 다시
// 계산됨. Left를 늘리면 액자 그리드 6칸 전체가 오른쪽으로, Top을 늘리면 전체가
// 아래로 같이 이동함(6칸이 통째로 움직임, 한 칸만 따로는 안 움직임)
const double _frameGridLeftRef = 181;
const double _frameGridTopRef = 73.5;

// 위쪽 줄(piece_1/6/5, 정사각형 308x308 원본)만 아래로 살짝 내리는 보정값(레퍼런스).
// 아래쪽 줄(piece_2/3/4)은 원본이 308x304라 BoxFit.contain으로 77x76까지만 그려지고
// 77 높이 박스 안에서 위아래로 0.5씩 여백(레터박스)이 생김. 그래서 박스 간격
// (_frameRowGapRef=1)만 맞춰도 실제 보이는 줄 간격은 1 + 0.5(아래줄 위쪽 여백) = 1.5px가
// 됨. 위쪽 줄을 이 값만큼 내리면 위쪽 줄 이미지 아래쪽 끝이 0.5px 내려가서 보이는
// 간격이 정확히 1px로 맞춰짐
const double _topRowDropForVisualGapRef = 0.5;

// 조각 6개의 정답 위치 레퍼런스(왼쪽 액자, 3열x2행 그리드, 화면 비율 874:402 기준).
// index는 diary_puzzle_piece_1~6에 순서대로 대응(0-based). 디자이너가 준 성공 배치
// 좌표(874x655 기준)를 그리드 칸에 배정한 값인데, 조각 번호 순서와 그리드 칸 순서가
// 일치하지 않음(piece_1=1행1열, piece_6=1행2열, piece_5=1행3열, piece_3=2행1열,
// piece_2=2행2열, piece_4=2행3열). x/y 둘 다 build()에서 _bgAnchorX/Y, _bgSize로
// 실제 화면 비율에 맞게 다시 계산됨. 전부 _frameGridLeft/TopRef + 그리드 칸 수로
// 계산되는 수식이라, 6칸을 통째로 옮기려면 위쪽 _frameGridLeft/TopRef를 바꾸면 됨.
// 특정 조각 하나만 따로 옮기고 싶으면 해당 줄의 Offset(...) 계산식을 원하는 좌표
// 숫자로 직접 바꿔주면 됨(그 줄만 그리드 계산에서 빠지고 고정값을 쓰게 됨)
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

// 조각 6개의 시작 위치 레퍼런스(오른쪽 트레이, 2열 배치, 화면 비율 874:402 기준).
// 디자이너가 준 초기 위치 좌표(874x655 기준)를 캔버스 좌표로 변환한 값. 정답 위치
// 그리드와 달리 칸 간격이 완전히 균일하진 않아서(디자이너 실측값 그대로 반영, 1px
// 내외 오차 있음) 수식이 아닌 좌표 그대로 씀. x/y 둘 다 build()에서 실제 화면
// 비율에 맞게 다시 계산됨. 특정 조각의 시작 위치만 옮기고 싶으면 해당 줄의
// Offset(...)을 직접 바꿔주면 됨
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

// 조각을 드롭했을 때 정답 위치로 스냅되는 허용 범위. 조각 가로 크기 대비 비율.
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

// 6조각 다 스냅되고 나서, 화면이 diary_puzzle_completed_bg.png(사진이 액자에 자연스럽게
// 붙어있는 일기장 전체 배경)로 바뀐 채 유지되는 시간. 이 다음 diary_puzzle_completed.png로
// 확대되는 단계로 넘어감
const Duration _completedBgHoldDuration = Duration(seconds: 1);
// diary_puzzle_completed.png로 확대된 채, SUCCESS 배너가 뜨기 전까지 잠깐 유지되는 시간
// (확대 연출과 SUCCESS 배너가 동시에 뜨지 않고 살짝 텀을 두기 위함)
const Duration _zoomHoldDuration = Duration(milliseconds: 800);
// SUCCESS 배너 노출 유지 시간. 이 값을 조정하면 SUCCESS 배너가 뜨고 나서 widget.onComplete()가
// 호출되어 다음 화면(kitchen_screen.dart의 결과 이미지 -> 암전 -> chapter3_after_eat.json)으로
// 넘어가기까지의 대기 시간이 바뀜. diary_puzzle_completed.png는 이 단계 내내 화면에
// 그대로 유지되므로(SUCCESS 배너만 위에 얹힘), 이 값을 늘리면 diary_puzzle_completed가
// 화면에 보이는 총 시간(_zoomHoldDuration + 이 값)도 같이 늘어남
const Duration _successHoldDuration = Duration(milliseconds: 1800);

class DiaryPuzzleScene extends StatefulWidget {
  const DiaryPuzzleScene({super.key, required this.onComplete});

  // 조각 6개를 다 맞추고 SUCCESS 연출까지 끝나면 호출됨. 다음 화면 전환은 호출부 책임
  final VoidCallback onComplete;

  @override
  State<DiaryPuzzleScene> createState() => _DiaryPuzzleSceneState();
}

class _DiaryPuzzleSceneState extends State<DiaryPuzzleScene> {
  // 조각 6개의 현재 위치(캔버스 874x402 좌표계, 왼쪽 위 모서리 기준, 이미 실제 화면
  // 비율만큼 보정된 값). LayoutBuilder가 실제 w/h를 알려주는 첫 build()에서
  // _pieceStartPositionsRef를 화면 비율에 맞게 변환해 한 번만 채워짐(그 전엔 빈 리스트)
  List<Offset> _piecePositions = [];
  bool _piecePositionsInitialized = false;
  // 조각 6개의 정답 위치(캔버스 874x402 좌표계, 실제 화면 비율로 매 build()마다
  // 다시 계산됨). _handlePieceDragEnd가 드래그 종료 시점에 최신 값을 읽어야 해서
  // build() 결과를 여기 저장해둠
  List<Offset> _pieceTargetPositions = List.of(_pieceTargetPositionsRef);
  // 스냅 허용 범위(캔버스 874x402 좌표계, 실제 화면 비율로 매 build()마다 다시 계산됨).
  // _handlePieceDragEnd가 드래그 종료 시점에 최신 값을 읽어야 해서 build() 결과를
  // 여기 저장해둠
  double _pieceSnapTolerance = _pieceWidthRef * _pieceSnapToleranceRatio;
  // 정답 위치에 스냅되어 고정된 조각 인덱스. 스냅되면 더 이상 드래그 안 됨
  final Set<int> _snappedPieces = {};
  // 6개 다 스냅된 뒤 순서대로 진행되는 3단계 완성 연출:
  // 1) 화면 전체가 diary_puzzle_completed_bg.png(사진이 액자에 자연스럽게 붙은 배경)로 바뀜
  // 2) diary_puzzle_completed.png(사진 클로즈업)로 전환됨
  // 3) SUCCESS 배너가 뜸(화면은 2번 상태 그대로 유지)
  bool _isCompletedBgActive = false;
  bool _isZoomedActive = false;
  bool _isSuccessActive = false;
  Timer? _completedBgTimer;
  Timer? _zoomTimer;
  Timer? _successTimer;
  bool _imagesPrecached = false;

  // 이미지 프리캐싱: 첫 빌드 시점에 한 번만 실행. 안 하면 Image.asset이 디코딩 끝날 때까지
  // 몇 프레임 동안 아무것도 안 그려서, 이 화면이 뜨는 순간 그 밑에 깔려있던 이전 화면(암전 등)이
  // 잠깐 비쳐 보이는 부자연스러운 전환이 생김
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

  // 조각 하나를 드래그하다 손을 뗐을 때: 정답 위치와의 거리가 허용 범위 안이면 스냅해서
  // 고정. 범위를 벗어나면 트레이로 되돌리지 않고 놓은 자리에 그대로 둠(다시 시도할 수
  // 있게, 갑자기 튕겨 돌아가는 것보다 자연스러워서 이렇게 함)
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

  // 6조각 다 스냅되면 시작: 완성된 배경(diary_puzzle_completed_bg)으로 전환 -> 확대
  // (diary_puzzle_completed) -> SUCCESS 배너 -> 적당한 시간 뒤 onComplete 자동 호출
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

        // diary_puzzle_bg.png가 실제 화면 비율(w/h)에 BoxFit.cover로 맞춰지면서 가로
        // 또는 세로가 잘리는 정도가 화면마다 달라서(어느 쪽이 잘리는지도 화면 비율에
        // 따라 바뀜), 액자/조각 관련 x/y값들은 여기서 실제 비율에 맞게 매번 다시 계산함
        // (자세한 설명은 파일 상단 _bgCoverScaleX/Y, _bgAnchorX/Y, _bgSize 주석 참고)
        final double bgScaleX = _bgCoverScaleX(w, h);
        final double bgScaleY = _bgCoverScaleY(w, h);
        final double pieceWidth = _bgSize(_pieceWidthRef, bgScaleX);
        final double pieceHeight = _bgSize(_pieceHeightRef, bgScaleY);
        final double frameColumnGap = _bgSize(_frameColumnGapRef, bgScaleX);
        final double frameRowGap = _bgSize(_frameRowGapRef, bgScaleY);
        final double frameGridLeft = _bgAnchorX(_frameGridLeftRef, bgScaleX);
        final double frameGridTop = _bgAnchorY(_frameGridTopRef, bgScaleY);
        final double topRowDrop = _bgSize(_topRowDropForVisualGapRef, bgScaleY);

        // 조각 6개 정답 위치. _pieceTargetPositionsRef와 동일한 그리드 배치 구조를
        // 실제 화면 비율에 맞게 다시 계산한 값
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

        // 조각 6개 시작 위치(트레이)도 동일하게 실제 화면 비율로 변환. 최초 1회만
        // _piecePositions를 채움(그 뒤로는 드래그/스냅으로 사용자가 직접 옮긴 값을 유지)
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

        // 이미 스냅된 조각은 항상 "지금 이 순간"의 정답 위치를 그대로 따라가게 함.
        // _piecePositions는 스냅되는 순간의 좌표값을 그대로 저장해두는 값이라, 스냅
        // 이후에 창 크기/비율이 바뀌면(예: 데스크톱에서 창을 리사이즈) 액자와 배경은
        // 새 비율로 다시 그려지는데 이미 스냅된 조각만 옛날 좌표에 그대로 남아서 액자와
        // 어긋나 보이는 문제가 있었음. 매 build마다 다시 맞춰주면 이 문제가 사라짐
        for (final index in _snappedPieces) {
          _piecePositions[index] = _pieceTargetPositions[index];
        }

        final bool isPuzzleComplete =
            _isCompletedBgActive || _isZoomedActive || _isSuccessActive;

        // 배경 3단계 순서대로 전환:
        // 1) 기본: diary_puzzle_bg.png(일기장 두 페이지, 조각을 맞추는 중)
        // 2) _isCompletedBgActive: diary_puzzle_completed_bg.png(사진이 액자에
        //    자연스럽게 붙어있는 완성된 배경)로 화면 전체가 바뀜
        // 3) _isZoomedActive/_isSuccessActive: diary_puzzle_completed.png(사진
        //    클로즈업)로 전환됨. SUCCESS 배너가 뜬 뒤(_isSuccessActive)에도 이
        //    화면은 그대로 유지됨
        // diary_puzzle_completed.png만 BoxFit.cover 대신 BoxFit.fitWidth를 씀 —
        // cover는 화면을 완전히 채우려고 상하좌우를 다 잘라내서 과하게 확대돼
        // 보였는데, fitWidth는 가로 폭만 화면에 딱 맞추고 세로는 원본 비율 그대로
        // 둬서 덜 확대돼 보임(세로가 화면보다 남거나 넘치는 만큼만 위아래가
        // 잘림). 나머지 두 배경(diary_puzzle_bg.png, diary_puzzle_completed_bg.png)은
        // 액자/조각 위치 계산이 전부 BoxFit.cover 기준으로 맞춰져 있어서 그대로 cover를 씀
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
              // if/else로 조건마다 별개의 Image 위젯을 새로 만들면(예전 방식), 단계가
              // 바뀔 때마다 Element 자체가 통째로 교체돼서 gaplessPlayback을 줘도 이전
              // 프레임을 붙들고 있을 대상이 없어 효과가 없었음(이미 프리캐싱된 이미지로
              // 바뀌는 순간에도 한 프레임 번쩍임). 그래서 Image 위젯 하나를 항상 그 자리에
              // 유지하고 image 경로(backgroundAsset)만 바꾸는 구조로 통일함 —
              // gaplessPlayback: true가 이 경우엔 실제로 새 프레임이 준비될 때까지 이전
              // 프레임을 그대로 붙들어줘서 틈이 안 생김
              Positioned.fill(
                child: Image.asset(
                  backgroundAsset,
                  fit: backgroundFit,
                  gaplessPlayback: true,
                ),
              ),

              // 조각 6개. 완성 이미지로 교체되기 전까지만 그리고, 스냅된 조각은 정답
              // 위치에 고정된 채 계속 보임(하나씩 맞춰지는 게 자연스럽게 보이도록)
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
