import 'consumable_data.dart';
import 'item.dart';
import 'item_data.dart';
import 'item_id.dart';

/// 장비 표(생성 파일)와 소비품 표(손으로 쓴 파일)를 합쳐 찾는다 (B6-05).
///
/// 가방에는 둘이 섞여 들어가므로 가방을 읽는 곳은 이것을 쓴다. 장비 슬롯만
/// 보는 곳(`equippedAt` 뒤)은 `itemById` 로 충분하다 — 소비품은 어느 부위에도
/// 못 가서 거기 있을 수 없다.
HDItem? lookupItem(HDItemId id) => itemById(id) ?? consumableById(id)?.item;
