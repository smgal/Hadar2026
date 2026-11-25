/// What a fight pays — ch.8.8.

/// `level³`.
///
/// Paid twice over an enemy's fall, to different people: once to the
/// member who knocked it unconscious, and again **to every member still
/// able to act** when an unconscious enemy is finished. There is no
/// victory bonus on top; experience has all been handed out by the time
/// the last enemy drops.
int knockOutExperience({required int enemyLevel}) =>
    enemyLevel * enemyLevel * enemyLevel;

/// `level³ × max(ac, 1)` for one fallen enemy, paid to the party once
/// on a win.
///
/// The original read another row's numbers here by mistake (appendix A
/// #3); this is the formula the chapter states.
int goldFor({required int enemyLevel, required int enemyAc}) =>
    enemyLevel * enemyLevel * enemyLevel * (enemyAc < 1 ? 1 : enemyAc);
