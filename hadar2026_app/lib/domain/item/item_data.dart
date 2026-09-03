// GENERATED — tools/convert_item.py 가 만든다. 손으로 고치지 말 것.
//
// 이름은 C++ 원작(`REF_hadar/src/hadar/hd_res_string.cpp`, CP949)에서,
// 수치는 Unity 포트(`REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs`)에서 온다.
// `assets/maps/books.json` 은 출처가 아니다 — 무기 5·방어구 3짜리 샘플이고
// 앱이 읽지도 않는다(GROUND_TRUTH 부록 H-3).
//
// **이름 공간과 수치는 원작에서 묶여 있지 않다.** C++ 은 `weapon` 정수를
// 이름 인덱스로만 쓰고 공격력은 `pow_of_weapon` 에 따로 넣는다
// (`hd_class_pc_player.cpp:212,451`). 실제로 배포된 스크립트가 같은
// `weapon=3` 에 `pow_of_weapon` 9(`L1_ep1d2.cm2:148`)와
// 100(`L1_ep1d0.cm2:169`)을 각각 넣는다. 아래 `attaPow` 는 **Unity 포트가
// 그 이름에 붙인 값**이지 C++ 이 정한 값이 아니다.

import 'item.dart';
import 'item_id.dart';
import 'item_type.dart';

/// 무기 이름 — `HDPlayer.weapon` 이 담는 정수의 이름 공간.
///
/// 출처: hd_res_string.cpp:43
const List<String> legacyWeaponNames = [
  '맨손', // 0
  '단도', // 1
  '곤봉', // 2
  '미늘창', // 3
  '장검', // 4
  '철퇴', // 5
  '기병창', // 6
  '도끼창', // 7
  '삼지창', // 8
  '화염검', // 9
];

/// 범위 밖 인덱스의 이름.
const String legacyUnknownWeaponName = '불확실한 무기';

/// 방패 이름 — `HDPlayer.shield` 가 담는 정수의 이름 공간.
///
/// 출처: hd_res_string.cpp:63
const List<String> legacyShieldNames = [
  '없음', // 0
  '가죽 방패', // 1
  '청동 방패', // 2
  '강철 방패', // 3
  '은제 방패', // 4
  '금제 방패', // 5
];

/// 범위 밖 인덱스의 이름.
const String legacyUnknownShieldName = '불확실한 방패';

/// 갑옷 이름 — `HDPlayer.armor` 가 담는 정수의 이름 공간.
///
/// index 0 만 C++ 의 '없음' 이 아니라 '평상복' 이다 — Unity 포트와
/// 현행 Dart(`player.dart:93`)가 이미 그 표기를 쓴다.
///
/// 출처: hd_res_string.cpp:79
const List<String> legacyArmorNames = [
  '평상복', // 0
  '가죽 갑옷', // 1
  '청동 갑옷', // 2
  '강철 갑옷', // 3
  '은제 갑옷', // 4
  '금제 갑옷', // 5
];

/// 범위 밖 인덱스의 이름.
const String legacyUnknownArmorName = '불확실한 갑옷';

/// 아이템 카탈로그.
///
/// `detail` 은 이 표에서 전부 0 이다. 원작은 `ResId` 의 타입 바이트가
/// 거친 태그(무기/방패/갑옷/장식)라 정확한 종류를 detail 로 되찾아야
/// 했지만(`ObjItem.cs:477,507,545-560` 이 각각 0 / 0 / HEAD=1 · LEG=2 를
/// 넣는다), 여기서는 `HDItemId.kind` 가 이미 정확하다. detail 은 향후
/// 세분류를 위해 비워 둔다.
final List<HDItem> itemTable = [
  // ---- 무기 ----
  HDItem(id: HDItemId(HDItemType.wield, index: 0), name: '맨손', param: HDItemParam(attaPow: 1, ac: 0, type: HDItemType.wield)), // ObjItem.cs:388
  HDItem(id: HDItemId(HDItemType.chop, index: 0), name: '맨손', param: HDItemParam(attaPow: 1, ac: 0, type: HDItemType.chop)), // ObjItem.cs:389
  HDItem(id: HDItemId(HDItemType.stab, index: 0), name: '맨손', param: HDItemParam(attaPow: 1, ac: 0, type: HDItemType.stab)), // ObjItem.cs:390
  HDItem(id: HDItemId(HDItemType.hit, index: 0), name: '맨손', param: HDItemParam(attaPow: 1, ac: 0, type: HDItemType.hit)), // ObjItem.cs:391
  HDItem(id: HDItemId(HDItemType.shoot, index: 0), name: '맨손', param: HDItemParam(attaPow: 1, ac: 0, type: HDItemType.shoot)), // ObjItem.cs:392
  HDItem(id: HDItemId(HDItemType.summonSingle, index: 0), name: '(없음)', param: HDItemParam(attaPow: 1, ac: 0, type: HDItemType.summonSingle)), // ObjItem.cs:393
  HDItem(id: HDItemId(HDItemType.summonMulti, index: 0), name: '(없음)', param: HDItemParam(attaPow: 1, ac: 0, type: HDItemType.summonMulti)), // ObjItem.cs:394
  HDItem(id: HDItemId(HDItemType.stab, index: 1), name: '단도', param: HDItemParam(attaPow: 10, ac: 0, type: HDItemType.stab)), // ObjItem.cs:423
  HDItem(id: HDItemId(HDItemType.hit, index: 3), name: '곤봉', param: HDItemParam(attaPow: 25, ac: 0, type: HDItemType.hit)), // ObjItem.cs:433
  HDItem(id: HDItemId(HDItemType.chop, index: 7), name: '미늘창', param: HDItemParam(attaPow: 80, ac: 0, type: HDItemType.chop)), // ObjItem.cs:421  Unity 는 '핼버드' 로 개명 — 이름은 C++ 을 따름
  HDItem(id: HDItemId(HDItemType.wield, index: 6), name: '장검', param: HDItemParam(attaPow: 60, ac: 0, type: HDItemType.wield)), // ObjItem.cs:412
  HDItem(id: HDItemId(HDItemType.chop, index: 5), name: '철퇴', param: HDItemParam(attaPow: 60, ac: 0, type: HDItemType.chop)), // ObjItem.cs:419
  HDItem(id: HDItemId(HDItemType.stab, index: 2), name: '기병창', param: HDItemParam(attaPow: 35, ac: 0, type: HDItemType.stab)), // ObjItem.cs:424
  HDItem(id: HDItemId(HDItemType.stab, index: 7), name: '도끼창', param: HDItemParam(attaPow: 90, ac: 0, type: HDItemType.stab)), // ObjItem.cs:429
  HDItem(id: HDItemId(HDItemType.stab, index: 5), name: '삼지창', param: HDItemParam(attaPow: 60, ac: 0, type: HDItemType.stab)), // ObjItem.cs:427
  HDItem(id: HDItemId(HDItemType.wield, index: 8), name: '화염검', param: HDItemParam(attaPow: 10, ac: 0, type: HDItemType.wield)), // ObjItem.cs:453  무기 표에 대응 항 없음 — SUMMON_SINGLE:8 의 자리표시 10.0(원작 TODO). 밸런스 값 아님
  // ---- 방패 ----
  HDItem(id: HDItemId(HDItemType.shield, index: 0), name: '없음', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.shield)), // ObjItem.cs:490
  HDItem(id: HDItemId(HDItemType.shield, index: 1), name: '가죽 방패', param: HDItemParam(attaPow: 0, ac: 1, type: HDItemType.shield)), // ObjItem.cs:491
  HDItem(id: HDItemId(HDItemType.shield, index: 2), name: '청동 방패', param: HDItemParam(attaPow: 0, ac: 2, type: HDItemType.shield)), // ObjItem.cs:492
  HDItem(id: HDItemId(HDItemType.shield, index: 3), name: '강철 방패', param: HDItemParam(attaPow: 0, ac: 3, type: HDItemType.shield)), // ObjItem.cs:493
  HDItem(id: HDItemId(HDItemType.shield, index: 4), name: '은제 방패', param: HDItemParam(attaPow: 0, ac: 4, type: HDItemType.shield)), // ObjItem.cs:494
  HDItem(id: HDItemId(HDItemType.shield, index: 5), name: '금제 방패', param: HDItemParam(attaPow: 0, ac: 5, type: HDItemType.shield)), // ObjItem.cs:495
  // ---- 갑옷 ----
  HDItem(id: HDItemId(HDItemType.armor, index: 0), name: '평상복', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.armor)), // ObjItem.cs:518
  HDItem(id: HDItemId(HDItemType.armor, index: 1), name: '가죽 갑옷', param: HDItemParam(attaPow: 0, ac: 1, type: HDItemType.armor)), // ObjItem.cs:519
  HDItem(id: HDItemId(HDItemType.armor, index: 2), name: '청동 갑옷', param: HDItemParam(attaPow: 0, ac: 2, type: HDItemType.armor)), // ObjItem.cs:520
  HDItem(id: HDItemId(HDItemType.armor, index: 3), name: '강철 갑옷', param: HDItemParam(attaPow: 0, ac: 3, type: HDItemType.armor)), // ObjItem.cs:521
  HDItem(id: HDItemId(HDItemType.armor, index: 4), name: '은제 갑옷', param: HDItemParam(attaPow: 0, ac: 4, type: HDItemType.armor)), // ObjItem.cs:522
  HDItem(id: HDItemId(HDItemType.armor, index: 5), name: '금제 갑옷', param: HDItemParam(attaPow: 0, ac: 5, type: HDItemType.armor)), // ObjItem.cs:523
  // ---- 머리 ----
  HDItem(id: HDItemId(HDItemType.head, index: 0), name: '없음', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:566
  HDItem(id: HDItemId(HDItemType.head, index: 1), name: '두건', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head), annex: 'ATT+1AC-1STR+1'), // ObjItem.cs:570
  HDItem(id: HDItemId(HDItemType.head, index: 2), name: '사냥 모자', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:571
  HDItem(id: HDItemId(HDItemType.head, index: 3), name: '반쪽 가면', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:572
  HDItem(id: HDItemId(HDItemType.head, index: 4), name: '중절모', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:573
  HDItem(id: HDItemId(HDItemType.head, index: 5), name: '가죽캡', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:574
  HDItem(id: HDItemId(HDItemType.head, index: 6), name: '가죽 투구', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:575
  HDItem(id: HDItemId(HDItemType.head, index: 7), name: '멋쟁이 모자', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:576
  HDItem(id: HDItemId(HDItemType.head, index: 8), name: '청동 투구', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:577
  HDItem(id: HDItemId(HDItemType.head, index: 9), name: '판금 투구', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:578
  HDItem(id: HDItemId(HDItemType.head, index: 10), name: '황금 왕관', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.head)), // ObjItem.cs:579
  // ---- 다리 ----
  HDItem(id: HDItemId(HDItemType.leg, index: 0), name: '없음', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:567
  HDItem(id: HDItemId(HDItemType.leg, index: 1), name: '헝겊 신발', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg), annex: 'INT-2'), // ObjItem.cs:581
  HDItem(id: HDItemId(HDItemType.leg, index: 2), name: '가죽 신발', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:582
  HDItem(id: HDItemId(HDItemType.leg, index: 3), name: '망사 스타킹', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:583
  HDItem(id: HDItemId(HDItemType.leg, index: 4), name: '날개 신발', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:584
  HDItem(id: HDItemId(HDItemType.leg, index: 5), name: '미늘 부츠', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:585
  HDItem(id: HDItemId(HDItemType.leg, index: 6), name: '다리6', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:586
  HDItem(id: HDItemId(HDItemType.leg, index: 7), name: '다리7', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:587
  HDItem(id: HDItemId(HDItemType.leg, index: 8), name: '다리8', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:588
  HDItem(id: HDItemId(HDItemType.leg, index: 9), name: '다리9', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:589
  HDItem(id: HDItemId(HDItemType.leg, index: 10), name: '다리A', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.leg)), // ObjItem.cs:590
  // ---- 장식 ----
  HDItem(id: HDItemId(HDItemType.ornament, index: 0), name: '없음', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:568
  HDItem(id: HDItemId(HDItemType.ornament, index: 1), name: '멋쟁이 혁띠', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament), annex: 'STR+100'), // ObjItem.cs:592
  HDItem(id: HDItemId(HDItemType.ornament, index: 2), name: '민무늬 반지', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:593
  HDItem(id: HDItemId(HDItemType.ornament, index: 3), name: '은 가락지', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:594
  HDItem(id: HDItemId(HDItemType.ornament, index: 4), name: '루비 목걸이', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:595
  HDItem(id: HDItemId(HDItemType.ornament, index: 5), name: '가짜 훈장', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:596
  HDItem(id: HDItemId(HDItemType.ornament, index: 6), name: '장식6', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:597
  HDItem(id: HDItemId(HDItemType.ornament, index: 7), name: '장식7', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:598
  HDItem(id: HDItemId(HDItemType.ornament, index: 8), name: '장식8', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:599
  HDItem(id: HDItemId(HDItemType.ornament, index: 9), name: '장식9', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:600
  HDItem(id: HDItemId(HDItemType.ornament, index: 10), name: '장식A', param: HDItemParam(attaPow: 0, ac: 0, type: HDItemType.ornament)), // ObjItem.cs:601
];

final Map<int, HDItem> _byWire = {
  for (final item in itemTable) item.id.wire: item,
};

/// 카탈로그에서 [id] 의 항을 찾는다. 없으면 null.
HDItem? itemById(HDItemId id) => _byWire[id.wire];

/// `HDPlayer.weapon` 정수 → 카탈로그 항.
///
/// index 0(맨손)은 다섯 무기 계열 모두에 있으나 정수 공간에는 계열이
/// 없으므로 `wield` 항을 대표로 가리킨다.
const List<HDItemId> legacyWeaponIds = [
  HDItemId(HDItemType.wield, index: 0), // 0
  HDItemId(HDItemType.stab, index: 1), // 1
  HDItemId(HDItemType.hit, index: 3), // 2
  HDItemId(HDItemType.chop, index: 7), // 3
  HDItemId(HDItemType.wield, index: 6), // 4
  HDItemId(HDItemType.chop, index: 5), // 5
  HDItemId(HDItemType.stab, index: 2), // 6
  HDItemId(HDItemType.stab, index: 7), // 7
  HDItemId(HDItemType.stab, index: 5), // 8
  HDItemId(HDItemType.wield, index: 8), // 9
];

/// `HDPlayer.shield` 정수 → 카탈로그 항.
const List<HDItemId> legacyShieldIds = [
  HDItemId(HDItemType.shield, index: 0), // 0
  HDItemId(HDItemType.shield, index: 1), // 1
  HDItemId(HDItemType.shield, index: 2), // 2
  HDItemId(HDItemType.shield, index: 3), // 3
  HDItemId(HDItemType.shield, index: 4), // 4
  HDItemId(HDItemType.shield, index: 5), // 5
];

/// `HDPlayer.armor` 정수 → 카탈로그 항.
const List<HDItemId> legacyArmorIds = [
  HDItemId(HDItemType.armor, index: 0), // 0
  HDItemId(HDItemType.armor, index: 1), // 1
  HDItemId(HDItemType.armor, index: 2), // 2
  HDItemId(HDItemType.armor, index: 3), // 3
  HDItemId(HDItemType.armor, index: 4), // 4
  HDItemId(HDItemType.armor, index: 5), // 5
];
