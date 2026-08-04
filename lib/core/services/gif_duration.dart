// lib/core/services/gif_duration.dart

import 'dart:ui' as ui;
import 'package:flutter/services.dart';

// GIF 에셋 하나를 통째로 디코딩해서 프레임별 duration을 다 더한 총 재생 시간을 구해줌.
// Image.asset은 GIF가 끝났을 때 알려주는 콜백이 없어서, 재생 시간을 하드코딩하는 대신
// 이 값으로 Timer를 걸어서 "재생 끝남"을 흉내내는 용도로 씀
class GifDuration {
  // asset 경로만 넘기면 그 GIF 한 바퀴(전체 프레임) 재생에 걸리는 시간을 ms로 반환
  static Future<int> totalMs(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    int totalMs = 0;
    for (int i = 0; i < codec.frameCount; i++) {
      final ui.FrameInfo frame = await codec.getNextFrame();
      totalMs += frame.duration.inMilliseconds;
    }
    codec.dispose();
    return totalMs;
  }
}
