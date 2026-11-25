import 'package:flutter/foundation.dart';

/// 음악과 효과음 — **지금은 소리를 내지 않는다.**
///
/// 원작은 AdLib 음악을 재생하는 반복 안에서 키 입력을 확인했다(부록 D.3).
/// 그 반복은 옮기지 않는다. 남기는 것은 「이 자리에서 이 곡이 시작된다」는
/// 사실뿐이고, 스크립트의 `Music::Play("town")` 이 그것을 여기에 적는다.
///
/// 소리를 붙일 때 고칠 곳은 이 파일 하나다 — 부르는 쪽(스크립트 · 전투 ·
/// 맵 전환)은 이미 다 부르고 있다.
class HDAudio {
  static final HDAudio _instance = HDAudio._internal();
  factory HDAudio() => _instance;
  HDAudio._internal();

  /// 지금 흐르고 있어야 할 곡. 맵을 옮기면 스크립트가 다시 정한다.
  String? currentMusic;

  /// 마지막으로 울린 효과음. 시험이 「불렸는가」를 볼 때 쓴다.
  String? lastSound;

  /// 받은 호출의 수. 0 이 아니면 누군가 불렀다는 뜻이다.
  int musicCalls = 0;
  int soundCalls = 0;

  void playMusic(String name) {
    musicCalls++;
    if (currentMusic == name) return; // 같은 곡이면 처음부터 다시 틀지 않는다
    currentMusic = name;
    debugPrint('[audio] music → $name (소리 없음)');
  }

  void stopMusic() {
    musicCalls++;
    if (currentMusic == null) return;
    currentMusic = null;
    debugPrint('[audio] music stop');
  }

  void playSound(String name) {
    soundCalls++;
    lastSound = name;
    debugPrint('[audio] sound → $name (소리 없음)');
  }

  @visibleForTesting
  void reset() {
    currentMusic = null;
    lastSound = null;
    musicCalls = 0;
    soundCalls = 0;
  }
}
