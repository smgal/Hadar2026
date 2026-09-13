/// 플래그 하나의 **정의**.
///
/// ## 왜 정의가 따로 필요한가
///
/// 게임이 아는 것은 번호뿐이다. `Flag::Set(41)` 은 41번을 켤 뿐이고,
/// 그것이 무엇을 뜻하는지는 그 줄 옆의 주석과 사람의 기억에만 있다.
/// `flag4ep1.cm2` 가 이름을 붙이지만 이름도 `GFD4_JOINNED_SOUL_OF_WATER`
/// 까지다 — **언제 켜지는지 · 켜지면 무엇이 열리는지 · 지금 켜져 있는
/// 것이 정상인지**는 아무 데도 없다.
///
/// 시나리오를 손으로 조정하려면 그 셋이 있어야 한다. 없으면 번호를 켜
/// 놓고 게임을 다시 돌려 보는 수밖에 없다.
///
/// ## 런타임이 아니라 저작 자료다
///
/// 게임은 이 표를 읽지 않는다. cm2 는 지금처럼 번호로 돈다. 이 표는
/// **사람과 도구**를 위한 것이고, 그래서 어긋날 수 있다 — 어긋나지
/// 않게 하는 것은 `flag4ep1.cm2` 를 실제로 읽어 맞춰 보는 시험이다
/// (`test/quest_registry_test.dart`).
library;

/// 무엇으로 세는가.
enum FlagKind {
  /// 켜졌나 꺼졌나. cm2 의 `Flag::Set` · `Flag::Reset` · `Flag::IsSet`.
  toggle,

  /// 몇 번째 단계인가. cm2 의 `Variable::Set` · `Variable::Add` ·
  /// `Variable::Get`.
  ///
  /// 값 하나가 **여러 사실**을 담는다 — 3이면 1과 2는 끝났고 3을 하는
  /// 중이다. 켜짐/꺼짐 여럿으로 쪼개지 않는 것은 원작이 그렇게 쓰기
  /// 때문이고(`lore_ep1.cm2` 의 10번), 단계는 건너뛸 수 없다는 사실을
  /// 값 하나가 스스로 지키기 때문이다.
  step,
}

/// 이 플래그가 실제로 게임 안에 있는가.
enum FlagStatus {
  /// cm2 가 지금 읽고 쓴다. `flag4ep1.cm2` 에 이름이 있다.
  live,

  /// cm2 가 **번호로** 읽고 쓰는데 이름이 없다. 고칠 때 무엇을 건드리는지
  /// 모르는 상태라 새 플래그를 그 번호에 얹기 쉽다.
  unnamed,

  /// 아직 어느 스크립트도 쓰지 않는다. 기획만 있다.
  planned,
}

/// 플래그 한 칸.
class FlagDef {
  const FlagDef({
    required this.scope,
    required this.index,
    required this.kind,
    required this.title,
    required this.detail,
    this.cm2Name = '',
    this.status = FlagStatus.live,
    this.where = '',
    this.scripts = const [],
    this.steps = const [],
    this.grants = const [],
    this.note = '',
  });

  /// 어디에 속하는가. 사람이 읽는 번호의 앞자리다 — `D4` · `L` · `W`.
  final String scope;

  /// cm2 가 쓰는 **진짜 번호**. 이것이 신원이다.
  final int index;

  final FlagKind kind;

  /// `GFD4_JOINNED_SOUL_OF_WATER`. 없으면 빈 문자열.
  final String cm2Name;

  final FlagStatus status;

  /// 한 줄 이름.
  final String title;

  /// **언제 켜지는가.** 조건이 아니라 사람이 한 일로 적는다 —
  /// 「41번이 1이면」 이 아니라 「물의 정령에게 호의를 보였다」 로.
  final String detail;

  /// 어디서 일어나는가.
  final String where;

  /// 이 번호를 건드리는 스크립트.
  final List<String> scripts;

  /// [FlagKind.step] 일 때 각 단계 한 줄. 0번 칸이 값 0 이다.
  final List<String> steps;

  /// 켜지면 파티가 얻는 것. `hd_world` 의 `Capability` 이름을 쓴다.
  ///
  /// **이것이 시나리오가 활동 반경을 넓히는 길이다.** 물 위를 걷는 것이
  /// 부적과 마법에 이어 세 번째 출처를 갖게 된 까닭이고, 그래서
  /// 모델이 아니라 여기에 적힌다 — `hd_world` 는 플래그를 모른다.
  final List<String> grants;

  /// 읽는 사람에게 알려야 할 것. 번호 충돌 같은 것.
  final String note;

  /// 사람이 부르는 번호. `D4-041` · `W-010`.
  String get id => '$scope-${index.toString().padLeft(3, '0')}';

  bool get isStep => kind == FlagKind.step;

  /// 단계 몇 개짜리인가. 토글은 0.
  int get stepCount => steps.length;

  Map<String, Object?> toJson() => {
    'id': id,
    'scope': scope,
    'index': index,
    'kind': kind.name,
    'status': status.name,
    'cm2Name': cm2Name,
    'title': title,
    'detail': detail,
    'where': where,
    'scripts': scripts,
    'steps': steps,
    'grants': grants,
    'note': note,
  };
}
