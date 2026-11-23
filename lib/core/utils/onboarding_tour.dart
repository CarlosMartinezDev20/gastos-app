import 'dart:math' as math;
import 'dart:ui';

import 'mascot_insights.dart';

/// The parts of the app the first-run tour points at. Each is marked in the
/// UI with a `TourTarget` (`widgets/onboarding_tour.dart`).
enum TourSpot {
  balance,
  add,
  history,
  goals,
  analysis,
  wallet,
  customize,
  profile,
}

/// One step of the tour: Michi explains [spot] (or, without one, talks in
/// the middle of the screen).
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    this.spot,
    this.mood = MascotMood.happy,
    this.reaction = MascotReaction.jump,
    this.celebrate = false,
  });

  final TourSpot? spot;
  final String title;
  final String body;
  final MascotMood mood;

  /// What Michi does when the step appears.
  final MascotReaction reaction;

  /// Confetti instead (the last step).
  final bool celebrate;
}

/// What Michi says when it's tapped during the tour, in turn.
const tourQuips = [
  '¡Miau! Sigamos.',
  '¡Jeje, cosquillas!',
  'Mantenme presionado para acariciarme.',
  'Ahorrar es purr-fecto.',
  'Prrr… estoy aquí si me necesitas.',
];

const onboardingSteps = <TourStep>[
  TourStep(
    title: '¡Hola, soy Michi!',
    body:
        'Te enseño en un minuto cómo llevar tus cuentas aquí. Tócame si '
        'quieres jugar, o salta el recorrido cuando quieras.',
    mood: MascotMood.excited,
    reaction: MascotReaction.wave,
  ),
  TourStep(
    spot: TourSpot.balance,
    title: 'Tu saldo',
    body:
        'Es lo que recibes menos lo que gastas. Aquí también te doy '
        'consejos: tócame cuando quieras uno.',
    reaction: MascotReaction.jump,
  ),
  TourStep(
    spot: TourSpot.add,
    title: 'Registra un movimiento',
    body:
        'Con + anotas un gasto o un ingreso en segundos. También puedes '
        'escanear una factura o hacer que se repita cada mes.',
    reaction: MascotReaction.jump,
  ),
  TourStep(
    spot: TourSpot.history,
    title: 'Historial',
    body:
        'Todos tus movimientos, día por día. Búscalos, fíltralos o desliza '
        'uno hacia la izquierda para borrarlo.',
    mood: MascotMood.calm,
    reaction: MascotReaction.wiggle,
  ),
  TourStep(
    spot: TourSpot.goals,
    title: 'Metas',
    body:
        'Ahorra para algo concreto: crea una meta, ponle fecha y ve '
        'apartando dinero. Te digo si vas a tiempo.',
    reaction: MascotReaction.jump,
  ),
  TourStep(
    spot: TourSpot.analysis,
    title: 'Análisis',
    body:
        'Mira en qué se va tu dinero, ponle un límite a cada categoría y '
        'arma tu presupuesto con la calculadora.',
    mood: MascotMood.calm,
    reaction: MascotReaction.wiggle,
  ),
  TourStep(
    spot: TourSpot.wallet,
    title: 'Mi wallet',
    body:
        'Agrega tus tarjetas y tu efectivo para saber con qué pagaste, '
        'cuánto debes y cuándo vence la tarjeta.',
    reaction: MascotReaction.wave,
  ),
  TourStep(
    spot: TourSpot.customize,
    title: 'Tu inicio, a tu gusto',
    body:
        'Elige qué ver aquí, su tamaño y su color. También puedes mantener '
        'presionada una tarjeta para editarla.',
    reaction: MascotReaction.wiggle,
  ),
  TourStep(
    spot: TourSpot.profile,
    title: 'Tu perfil',
    body:
        'Colores y tema, recordatorios, bloqueo con huella y tu cuenta. Desde '
        'aquí puedes repetir este recorrido.',
    mood: MascotMood.calm,
    reaction: MascotReaction.wave,
  ),
  TourStep(
    title: '¡Todo listo!',
    body:
        'Empieza registrando tu primer movimiento. Mientras más anotes, '
        'mejores consejos te doy.',
    mood: MascotMood.excited,
    celebrate: true,
  ),
];

/// SharedPreferences flag: the tour already started for this user on this
/// device (it isn't offered again on its own; Perfil can replay it).
String onboardingDoneKey(String userId) => 'onboarding_done_$userId';

/// Only someone who hasn't recorded anything yet gets the tour on their own.
bool shouldAutoStartTour({required bool seen, required bool hasMovements}) =>
    !seen && !hasMovements;

/// The indexes of the [steps] to show: those without a spot and those
/// whose spot is on screen ([available]), e.g. not the balance step if the
/// balance card was removed from Inicio.
List<int> tourStepsOnScreen(
  List<TourStep> steps,
  bool Function(TourSpot spot) available,
) => [
  for (final (i, step) in steps.indexed)
    if (step.spot == null || available(step.spot!)) i,
];

/// Where the tour's card goes: below or above the highlighted [hole],
/// whichever has more room inside [safe] (the screen minus system bars),
/// [gap] away from it. Without a hole, or when neither side has [minRoom],
/// the whole of [safe] (the card then sits over the hole if need be). The
/// card is aligned to the returned rect's top when [below], and to its
/// bottom otherwise.
({Rect area, bool below}) tourCardArea({
  required Rect safe,
  Rect? hole,
  double gap = 16,
  double minRoom = 180,
}) {
  if (hole == null) return (area: safe, below: false);
  final above = hole.top - gap - safe.top;
  final below = safe.bottom - (hole.bottom + gap);
  if (math.max(above, below) < minRoom) return (area: safe, below: false);
  return below >= above
      ? (
          area: Rect.fromLTRB(
            safe.left,
            hole.bottom + gap,
            safe.right,
            safe.bottom,
          ),
          below: true,
        )
      : (
          area: Rect.fromLTRB(safe.left, safe.top, safe.right, hole.top - gap),
          below: false,
        );
}

/// Where Michi looks, from −1 to 1 each way (as `Mascot.gaze`), standing at
/// [from] and looking at [to]: straight at it once it's more than a
/// little away.
Offset tourGaze(Offset from, Offset to) {
  final towards = to - from;
  final distance = towards.distance;
  if (distance < 1) return Offset.zero;
  return towards / distance * math.min(1.0, distance / 120);
}
