import 'package:flutter/material.dart';

import '../../hd_config.dart';

/// 맵이 없을 때 맵 자리에 놓는 제목 그림.
///
/// 제목 화면 · 캐릭터 만들기 · 엔딩 뒤에 보인다. 원작의 제목 그림은 이
/// 저장소에 없으므로 글자로 대신한다 — 그림이 생기면 이 위젯만 바꾸면 된다.
class HDTitlePanel extends StatelessWidget {
  const HDTitlePanel({super.key, this.error});

  /// 맵을 불러오다 실패했을 때의 까닭. 있으면 제목 아래에 적는다.
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.mapViewportWidth,
      height: HDConfig.mapViewportHeight,
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '또 다른\n지식의 성전',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.amber.shade300,
              fontSize: 34,
              height: 1.25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '3부작',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 22),
          const Text(
            '1993  또 다른 지식의 성전\n'
            '1994  다크 메이지 실리안 카미너스\n'
            '1995  비전 속으로',
            textAlign: TextAlign.left,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
