import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/daily_game_service.dart';

/// What the daily "Game over" dialog is showing right now.
enum DailyRematchPhase {
  /// Nobody has offered yet: "Offer rematch" / "Not now".
  ask,

  /// My offer is being sent to the server.
  sending,

  /// My offer is out; waiting for the opponent to answer.
  waiting,

  /// The opponent declined my offer.
  declined,

  /// My offer ran out of time.
  expired,

  /// The opponent offered ME a rematch: "Accept" / "Decline".
  incoming,
}

/// Game-over dialog of a daily game. It stays open while the rematch is being
/// answered and changes by itself: waiting -> declined, or (when the opponent
/// accepts) the screen closes it and opens the new game directly.
class DailyRematchDialog extends StatelessWidget {
  final DailyGame game;
  final ValueListenable<DailyRematchPhase> phase;
  final VoidCallback onOffer; // ask / declined / expired -> send an offer
  final VoidCallback onCancel; // waiting -> withdraw my offer
  final VoidCallback onAccept; // incoming -> accept
  final VoidCallback onDecline; // incoming -> decline
  final VoidCallback onClose;

  const DailyRematchDialog({
    super.key,
    required this.game,
    required this.phase,
    required this.onOffer,
    required this.onCancel,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  });

  /// 1 = I won, -1 = I lost, 0 = draw.
  int get _outcome {
    final w = game.winnerId;
    if (w == null || w.isEmpty) return 0;
    return w == game.myId ? 1 : -1;
  }

  ({List<Color> colors, IconData icon, String headline, String sub}) _look(DailyRematchPhase p) {
    final opp = game.opponentName;
    switch (p) {
      case DailyRematchPhase.declined:
        return (
          colors: const [Color(0xFFE53935), Color(0xFF7F1D1D)],
          icon: Icons.block_rounded,
          headline: 'Declined',
          sub: '$opp declined the rematch',
        );
      case DailyRematchPhase.expired:
        return (
          colors: const [Color(0xFF607D8B), Color(0xFF37474F)],
          icon: Icons.timer_off_rounded,
          headline: 'Offer expired',
          sub: '$opp did not answer in time',
        );
      case DailyRematchPhase.waiting:
      case DailyRematchPhase.sending:
        return (
          colors: const [Color(0xFF1E88E5), Color(0xFF0D47A1)],
          icon: Icons.hourglass_top_rounded,
          headline: 'Rematch offered',
          sub: 'Waiting for $opp',
        );
      case DailyRematchPhase.incoming:
        return (
          colors: const [Color(0xFF43A047), Color(0xFF1B5E20)],
          icon: Icons.autorenew_rounded,
          headline: 'Rematch?',
          sub: '$opp wants to play again',
        );
      case DailyRematchPhase.ask:
        break;
    }
    switch (_outcome) {
      case 1:
        return (
          colors: const [Color(0xFFFFB300), Color(0xFFEF6C00)],
          icon: Icons.emoji_events_rounded,
          headline: 'Victory!',
          sub: game.resultText,
        );
      case -1:
        return (
          colors: const [Color(0xFFE53935), Color(0xFF7F1D1D)],
          icon: Icons.heart_broken_rounded,
          headline: 'Defeat',
          sub: game.resultText,
        );
      default:
        return (
          colors: const [Color(0xFF607D8B), Color(0xFF37474F)],
          icon: Icons.handshake_rounded,
          headline: 'Draw',
          sub: game.resultText,
        );
    }
  }

  Widget _bubble(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );

  Widget _hero(BuildContext context, DailyRematchPhase p) {
    final look = _look(p);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: look.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -60, left: -50, child: _bubble(150, 0.08)),
          Positioned(bottom: -70, right: -40, child: _bubble(170, 0.07)),
          Positioned(
            top: -16,
            right: -12,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              tooltip: 'Close',
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Column(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Container(
                  key: ValueKey(look.icon),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: Icon(look.icon, size: 42, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                look.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
              const SizedBox(height: 6),
              Text(
                look.sub,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, height: 1.3),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, String name, bool me) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Expanded(
      child: Column(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: me ? cs.primaryContainer : cs.surfaceContainerHighest,
          child: Text(
            initial,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: me ? cs.onPrimaryContainer : cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 6),
        Text(me ? 'You' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _versus(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _avatar(context, 'You', true),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('VS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
      ),
      _avatar(context, game.opponentName, false),
    ]);
  }

  Widget _note(BuildContext context, Widget child, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  ButtonStyle get _filled => FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      );

  ButtonStyle get _outlined => OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      );

  Widget _body(BuildContext context, DailyRematchPhase p) {
    final cs = Theme.of(context).colorScheme;
    final opp = game.opponentName;
    final nextColor = game.iAmWhite ? 'black' : 'white';
    switch (p) {
      case DailyRematchPhase.ask:
        return Column(key: const ValueKey('ask'), children: [
          _note(
            context,
            Row(children: [
              Icon(Icons.swap_horiz_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Play again with $opp? You will play $nextColor, and $opp can accept or decline.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(style: _outlined, onPressed: onClose, child: const Text('Not now'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: _filled,
                onPressed: onOffer,
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Offer rematch', maxLines: 1)),
              ),
            ),
          ]),
        ]);
      case DailyRematchPhase.sending:
        return Column(key: const ValueKey('sending'), children: [
          _note(
            context,
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
              SizedBox(width: 12),
              Text('Sending offer…'),
            ]),
          ),
        ]);
      case DailyRematchPhase.waiting:
        return Column(key: const ValueKey('waiting'), children: [
          _note(
            context,
            Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(width: 12),
                Flexible(child: Text('Waiting for $opp to answer…', style: Theme.of(context).textTheme.bodyLarge)),
              ]),
              const SizedBox(height: 6),
              Text(
                'The game starts by itself as soon as $opp accepts.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          OutlinedButton(style: _outlined, onPressed: onCancel, child: const Text('Cancel offer')),
        ]);
      case DailyRematchPhase.declined:
      case DailyRematchPhase.expired:
        final declined = p == DailyRematchPhase.declined;
        return Column(key: ValueKey(p.name), children: [
          _note(
            context,
            Row(children: [
              Icon(declined ? Icons.cancel_rounded : Icons.timer_off_rounded, color: declined ? cs.error : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  declined ? '$opp declined the rematch.' : 'The rematch offer expired.',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            color: declined ? cs.errorContainer.withValues(alpha: 0.55) : null,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(style: _outlined, onPressed: onClose, child: const Text('Close'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: _filled,
                onPressed: onOffer,
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Offer again', maxLines: 1)),
              ),
            ),
          ]),
        ]);
      case DailyRematchPhase.incoming:
        return Column(key: const ValueKey('incoming'), children: [
          _note(
            context,
            Row(children: [
              Icon(Icons.autorenew_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$opp wants a rematch (you play $nextColor).',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
                ),
              ),
            ]),
            color: cs.primaryContainer.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(style: _outlined, onPressed: onDecline, child: const Text('Decline'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(style: _filled, onPressed: onAccept, child: const Text('Accept'))),
          ]),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<DailyRematchPhase>(
      valueListenable: phase,
      builder: (context, p, _) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
              color: cs.surface,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _hero(context, p),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(children: [
                      _versus(context),
                      const SizedBox(height: 18),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _body(context, p)),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
