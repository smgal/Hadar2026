/// The vocabularies the shipped content still speaks.
///
/// Four thousand lines of script address the party by attribute name
/// and items by table position. Neither can be asked to change, and
/// neither belongs in `hd_world` — so the translation lives here, on
/// its own, where a test can walk the whole surface.
///
/// The rule this package exists to keep: **nothing is silently
/// ignored.** Every write comes back with a verdict, and a name that no
/// longer decides anything is told apart from a name that never
/// existed.
library;

export 'src/attribute.dart';
export 'src/legacy_item.dart';
