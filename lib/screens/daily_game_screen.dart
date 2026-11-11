import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/services/admin_service.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:flutter_chess_app/widgets/audio_controls_widget.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/daily_game_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/services/livekit_token_service.dart';
import 'package:flutter_chess_app/services/monetization_service.dart';
import 'package:flutter_chess_app/services/permission_service.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/widgets/audio_access_dialog.dart';
import 'package:flutter_chess_app/widgets/daily_game_widgets.dart';
import 'package:flutter_chess_app/widgets/daily_rematch_dialog.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/chat_screen.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chess_app/utils/uci_game.dart';
import 'package:flutter_chess_app/widgets/learn_board.dart';
import 'package:squares/squares.dart';

/// One daily game: the board, whose turn it is, and resign / draw. The server checks every move.
class DailyGameScreen extends StatefulWidget {
  final String gameId;
  const DailyGameScreen({super.key, required this.gameId});

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen> with WidgetsBindingObserver {
  final DailyGameService _service = DailyGameService();
  final UciGame _g = UciGame();
  DailyGame? _game;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  // Orientation is fixed by MY colour: squares(myColour) already puts me at the
  // bottom (white for white, black for black). The flip button only toggles this
  // extra manual flip, so a move never turns the board by itself.
  bool _manualFlip = false;
  Timer? _poll;
  StreamSubscription<Map<String, dynamic>>? _liveSub;

  // ---- Opponent online / offline (live in the app bar) ----
  bool? _oppOnline; // null = not known yet
  Timer? _presenceTimer;
  bool _appResumed = true;

  // ---- Chat with the opponent (same friend chat as everywhere else) ----
  int _unread = 0;
  StreamSubscription<Map<String, dynamic>>? _chatSub;

  // ---- Rematch (after the game is over) ----
  String? _rematchId; // the rematch offer I sent
  DailyGame? _rematchGame;
  bool _rematchGone = false; // my offer no longer exists on the server
  DailyGame? _incoming; // a rematch offer the opponent sent ME
  Timer? _rematchTimer;
  bool _rematchPrompted = false;
  final ValueNotifier<DailyRematchPhase> _phase = ValueNotifier(DailyRematchPhase.ask);
  Timer? _waitTimer; // fast poll (3 s) only while my offer is waiting for an answer
  bool _dialogOpen = false;
  BuildContext? _dialogCtx;
  bool _navigating = false; // already moving to the rematch game
  String get _rematchKey => 'daily_rematch_${widget.gameId}';

  // ---- Voice chat (LiveKit) ----
  lk.Room? _voiceRoom;
  bool _inVoice = false;
  bool _voiceBusy = false;
  bool _micOn = true;
  bool _speakerMuted = false;
  bool _tempVoiceAccess = false;
  bool _adGateEnabled = true;
  StreamSubscription<bool>? _adGateSub;

  // NOTE: do NOT also flip for black here. _g.squares(1) is already turned for
  // black, so flipping again showed white at the bottom for BOTH players.
  bool get _flipped => _manualFlip;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Live: the server tells us over socket.io ('daily:update') the moment the
    // opponent moves, offers a draw, resigns, etc.
    _liveSub = GameSocketService.instance.onDailyUpdate.listen((d) {
      // Finished game: a rematch offer / answer (a different game id) may have arrived.
      if (_game?.status == 'completed') {
        _syncRematch();
        return;
      }
      final id = d['gameId']?.toString();
      if (id == null || id.isEmpty || id == widget.gameId) _refreshQuiet();
    });
    // Slow safety net only (missed socket event / reconnect), not the main mechanism.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refreshQuiet());
    _presenceTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _checkPresence();
      _checkUnread();
    });
    _chatSub = GameSocketService.instance.onChatMessage.listen((_) => _checkUnread());
    _adGateSub = AdminService().watchVoiceChatAdGateEnabled().listen((v) {
      if (mounted) setState(() => _adGateEnabled = v);
    }, onError: (_) {});
    _restoreRematch();
  }

  Future<void> _restoreRematch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_rematchKey);
      if (id != null && id.isNotEmpty && mounted) setState(() => _rematchId = id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    _presenceTimer?.cancel();
    _rematchTimer?.cancel();
    _waitTimer?.cancel();
    _chatSub?.cancel();
    _adGateSub?.cancel();
    _liveSub?.cancel();
    _voiceRoom?.disconnect();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed) {
      _refreshQuiet();
      _checkPresence();
    }
  }

  /// Unread chat messages from the opponent (badge on the Chat button).
  Future<void> _checkUnread() async {
    final g = _game;
    if (!mounted || !_appResumed || g == null || g.opponentId.isEmpty) return;
    try {
      final r = await ApiClient.instance.get('/chat/${g.opponentId}/unread-count');
      final c = (r['count'] as num?)?.toInt() ?? 0;
      if (mounted && c != _unread) setState(() => _unread = c);
    } catch (_) {}
  }

  Future<void> _openChat() async {
    final g = _game;
    final me = context.read<UserProvider>().user;
    if (g == null || g.opponentId.isEmpty) return;
    if (me == null) {
      _toast('Sign in to chat.');
      return;
    }
    ChessUser? opp;
    try {
      opp = await UserService().getUserById(g.opponentId);
    } catch (_) {}
    opp ??= ChessUser(uid: g.opponentId, displayName: g.opponentName);
    if (!mounted) return;
    final other = opp;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: ChatScreen(currentUser: me, otherUser: other, showInvite: false),
      ),
    );
    _checkUnread(); // the chat marks messages as read while it is open
  }

  /// Asks the server whether the opponent is online right now (also polled every 6 s).
  Future<void> _checkPresence() async {
    final g = _game;
    if (!mounted || !_appResumed || g == null || g.opponentId.isEmpty) return;
    try {
      final u = await UserService().getUserById(g.opponentId);
      if (!mounted || u == null) return;
      if (_oppOnline != u.isOnline) setState(() => _oppOnline = u.isOnline);
    } catch (_) {}
  }

  /// Background refresh: never shows errors and never interrupts a move in progress.
  Future<void> _refreshQuiet() async {
    if (!mounted || _busy) return;
    final g = _game;
    if (g != null && !g.isActive) return; // finished / not started: nothing to wait for
    try {
      final fresh = await _service.get(widget.gameId);
      if (!mounted || _busy) return;
      final old = _game;
      final changed = old == null ||
          fresh.moves.length != old.moves.length ||
          fresh.status != old.status ||
          fresh.myTurn != old.myTurn ||
          fresh.drawOfferedBy != old.drawOfferedBy;
      if (changed) _apply(fresh);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      _apply(await _service.get(widget.gameId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  void _apply(DailyGame g) {
    if (!mounted) return;
    final wasActive = _game?.isActive ?? false;
    final firstLoad = _game == null;
    _g.rebuild(g.moves);
    setState(() {
      // A manual flip only lasts while the game is on; when it ends the board goes back to my colour.
      if (g.status == 'completed' && wasActive) _manualFlip = false;
      _game = g;
      _loading = false;
      _error = null;
    });
    if (firstLoad) {
      _checkPresence();
      _checkUnread();
    }
    if (g.status == 'completed' && !g.inTournament) {
      if (_inVoice) _leaveVoice();
      _rematchTimer ??= Timer.periodic(const Duration(seconds: 8), (_) => _syncRematch());
      _syncRematch();
      // The game has just ended (resign / draw / checkmate / time): offer a rematch.
      if (wasActive && !_rematchPrompted) {
        _rematchPrompted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showRematchDialog());
      }
    }
  }

  // ------------------------- Rematch -------------------------

  DailyRematchPhase _computePhase() {
    if (_incoming != null) return DailyRematchPhase.incoming;
    if (_rematchId == null) return _busy ? DailyRematchPhase.sending : DailyRematchPhase.ask;
    final r = _rematchGame;
    if (_rematchGone || r?.status == 'declined') return DailyRematchPhase.declined;
    if (r?.status == 'expired') return DailyRematchPhase.expired;
    return DailyRematchPhase.waiting;
  }

  /// Call after every rematch change: updates the open dialog, runs the fast poll only while
  /// waiting, and opens the new game by itself the moment the opponent accepts.
  void _rematchChanged() {
    if (!mounted || _navigating) return;
    final phase = _computePhase();
    _phase.value = phase;
    final r = _rematchGame;
    if (_rematchId != null && r != null && r.id == _rematchId && r.status == 'active') {
      _openGame(r.id); // accepted: dialog closes, game starts directly
      return;
    }
    if (phase == DailyRematchPhase.waiting) {
      _waitTimer ??= Timer.periodic(const Duration(seconds: 3), (_) => _syncRematch(listToo: false));
    } else {
      _waitTimer?.cancel();
      _waitTimer = null;
    }
  }

  Future<void> _syncRematch({bool listToo = true}) async {
    final g = _game;
    if (!mounted || g == null || g.isActive || g.inTournament || _navigating) return;
    if (_rematchId != null) {
      try {
        final r = await _service.get(_rematchId!);
        if (mounted) setState(() {
          _rematchGame = r;
          _rematchGone = false;
        });
      } on ApiException catch (e) {
        if (e.statusCode == 404 && mounted) setState(() => _rematchGone = true);
      } catch (_) {}
    }
    if (listToo) {
      try {
        final list = await _service.list();
        final found = list.invites.where((x) =>
            x.id != g.id &&
            !x.inTournament &&
            ((x.whiteId == g.whiteId && x.blackId == g.blackId) || (x.whiteId == g.blackId && x.blackId == g.whiteId)));
        if (mounted) setState(() => _incoming = found.isEmpty ? null : found.first);
      } catch (_) {}
    }
    _rematchChanged();
  }

  void _closeDialog() {
    final c = _dialogCtx;
    if (!_dialogOpen || c == null || !c.mounted) return;
    _dialogOpen = false;
    _dialogCtx = null;
    Navigator.of(c).pop();
  }

  Future<void> _showRematchDialog() async {
    final g = _game;
    if (!mounted || g == null || _dialogOpen) return;
    _dialogOpen = true;
    _phase.value = _computePhase();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        _dialogCtx = ctx;
        return DailyRematchDialog(
          game: g,
          phase: _phase,
          onOffer: () async {
            if (_rematchId != null) await _clearRematch(notify: false); // declined / expired: start fresh
            await _offerRematch();
          },
          onCancel: _cancelRematch,
          onAccept: () => _answerIncoming(true),
          onDecline: () => _answerIncoming(false),
          onClose: _closeDialog,
        );
      },
    );
    _dialogOpen = false;
    _dialogCtx = null;
  }

  Future<void> _offerRematch() async {
    final g = _game;
    if (g == null || _busy) return;
    setState(() => _busy = true);
    _rematchChanged(); // dialog: "Sending offer..."
    try {
      final r = await _service.rematch(g);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_rematchKey, r.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _rematchId = r.id;
        _rematchGame = r;
        _rematchGone = false;
      });
      if (!_dialogOpen) _toast('Rematch offer sent to ${g.opponentName}.');
    } catch (e) {
      _toast(_err(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _rematchChanged(); // dialog: waiting (or back to the question if sending failed)
      }
    }
  }

  Future<void> _clearRematch({bool notify = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rematchKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rematchId = null;
      _rematchGame = null;
      _rematchGone = false;
    });
    if (notify) _rematchChanged();
  }

  Future<void> _cancelRematch() async {
    final id = _rematchId;
    if (id == null) return;
    try {
      await _service.decline(id);
    } catch (_) {}
    await _clearRematch();
  }

  /// Opens the rematch game straight away (closing the dialog first).
  void _openGame(String id) {
    if (_navigating || !mounted) return;
    _navigating = true;
    _waitTimer?.cancel();
    _waitTimer = null;
    _rematchTimer?.cancel();
    _closeDialog();
    _clearRematch(notify: false);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DailyGameScreen(gameId: id)));
  }

  Future<void> _answerIncoming(bool accept) async {
    final inc = _incoming;
    if (inc == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (accept) {
        final r = await _service.accept(inc.id);
        if (!mounted) return;
        _openGame(r.id);
        return;
      }
      await _service.decline(inc.id);
      if (mounted) {
        setState(() => _incoming = null);
        _toast('Rematch declined.');
      }
    } catch (e) {
      _toast(_err(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _rematchChanged();
      }
    }
  }

  Widget _rematchSection(DailyGame g) {
    final cs = Theme.of(context).colorScheme;
    Widget card(IconData icon, String text, List<Widget> actions, {Color? color}) => Card(
          color: color,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.end, children: actions),
              ],
            ]),
          ),
        );

    // The opponent asked ME for a rematch.
    if (_incoming != null) {
      return card(Icons.replay, '${g.opponentName} wants a rematch (you play ${_incoming!.myColor}).', [
        TextButton(onPressed: _busy ? null : () => _answerIncoming(false), child: const Text('Decline')),
        FilledButton(onPressed: _busy ? null : () => _answerIncoming(true), child: const Text('Accept')),
      ]);
    }

    // I sent a rematch offer: show the opponent's answer.
    if (_rematchId != null) {
      final r = _rematchGame;
      if (_rematchGone || r?.status == 'declined') {
        return card(Icons.cancel_outlined, '${g.opponentName} declined the rematch.', [
          TextButton(onPressed: _clearRematch, child: const Text('Close')),
          FilledButton(
            onPressed: _busy ? null : () async {
              await _clearRematch();
              await _offerRematch();
            },
            child: const Text('Offer again'),
          ),
        ], color: cs.errorContainer);
      }
      if (r?.status == 'expired') {
        return card(Icons.timer_off_outlined, 'The rematch offer expired.', [
          TextButton(onPressed: _clearRematch, child: const Text('Close')),
          FilledButton(
            onPressed: _busy ? null : () async {
              await _clearRematch();
              await _offerRematch();
            },
            child: const Text('Offer again'),
          ),
        ]);
      }
      if (r?.status == 'active') {
        return card(Icons.check_circle_outline, '${g.opponentName} accepted the rematch!', [
          FilledButton.icon(onPressed: () => _openGame(r!.id), icon: const Icon(Icons.play_arrow), label: const Text('Play now')),
        ], color: cs.primaryContainer);
      }
      return card(Icons.hourglass_top, 'Rematch offered. Waiting for ${g.opponentName} to answer…', [
        TextButton(onPressed: _cancelRematch, child: const Text('Cancel offer')),
      ]);
    }

    // Nothing sent yet.
    return Center(
      child: FilledButton.icon(
        onPressed: _busy ? null : _offerRematch,
        icon: const Icon(Icons.replay),
        label: const Text('Offer rematch'),
      ),
    );
  }

  // ------------------------- Voice chat -------------------------

  Future<void> _joinVoice() async {
    final g = _game;
    if (g == null || _voiceBusy || _inVoice) return;
    setState(() => _voiceBusy = true);
    lk.Room? room;
    try {
      final ps = PermissionService();
      final perm = await ps.requestMicrophonePermission(context);
      if (perm == PermissionResult.denied) {
        _toast('Microphone permission is required for voice chat');
        return;
      }
      if (perm == PermissionResult.permanentlyDenied) {
        if (mounted) await ps.handlePermanentlyDeniedPermission(context, 'Microphone');
        return;
      }
      if (!mounted) return;

      // Same unlock rule as the live game: free when the ad gate is off or the user has no ads.
      final user = context.read<UserProvider>().user;
      final needsUnlock = _adGateEnabled && MonetizationService.shouldShowAds(context, user) && !_tempVoiceAccess;
      if (needsUnlock) {
        final a = await AudioAccessDialog.show(context: context);
        if (a == AudioAccessAction.watchAd) {
          _tempVoiceAccess = true;
        } else {
          if (a == AudioAccessAction.premium) _toast('Visit Profile screen to upgrade to Premium');
          return;
        }
      }

      final cred = await LiveKitTokenService().getToken('daily_${g.id}');
      room = lk.Room();
      final listener = room.createListener();
      listener
        ..on<lk.ParticipantConnectedEvent>((_) { if (mounted) setState(() {}); })
        ..on<lk.ParticipantDisconnectedEvent>((_) { if (mounted) setState(() {}); })
        ..on<lk.TrackSubscribedEvent>((_) { if (mounted) setState(() {}); });
      await room.connect(cred.url, cred.token, roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true));
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _voiceRoom = room;
        _inVoice = true;
        _micOn = true;
        _speakerMuted = false;
      });
      _toast('Voice chat on. ${g.opponentName} can join from this game screen.');
    } catch (e) {
      try {
        await room?.disconnect();
      } catch (_) {}
      _toast('Voice chat failed: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  Future<void> _leaveVoice() async {
    final room = _voiceRoom;
    _voiceRoom = null;
    try {
      await room?.disconnect();
    } catch (_) {}
    if (mounted) setState(() {
      _inVoice = false;
      _micOn = true;
      _speakerMuted = false;
    });
  }

  Future<void> _toggleMic() async {
    final next = !_micOn;
    try {
      await _voiceRoom?.localParticipant?.setMicrophoneEnabled(next);
      if (mounted) setState(() => _micOn = next);
    } catch (e) {
      _toast('Could not change the microphone.');
    }
  }

  void _toggleSpeaker() {
    final next = !_speakerMuted;
    final room = _voiceRoom;
    if (room != null) {
      for (final p in room.remoteParticipants.values) {
        for (final pub in p.audioTrackPublications) {
          final t = pub.track;
          if (t is lk.RemoteAudioTrack) t.mediaStreamTrack.enabled = !next;
        }
      }
    }
    setState(() => _speakerMuted = next);
  }

  Widget _voiceBar() {
    final g = _game;
    final others = _voiceRoom?.remoteParticipants.length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Text(
          others > 0
              ? 'Voice chat · ${g?.opponentName ?? 'opponent'} connected'
              : 'Voice chat · waiting for ${g?.opponentName ?? 'opponent'} to join',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        AudioControlsWidget(
          isInAudioRoom: true,
          isMicrophoneEnabled: _micOn,
          isSpeakerMuted: _speakerMuted,
          onToggleMicrophone: _toggleMic,
          onToggleSpeaker: _toggleSpeaker,
          onLeaveAudio: _leaveVoice,
        ),
      ]),
    );
  }

  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<DailyGame> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _apply(await action());
    } catch (e) {
      _toast(_err(e));
      await _load(); // the server's copy is the truth: repair the board
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onMove(Move move) {
    final g = _game;
    if (g == null || !g.isActive || !g.myTurn || _busy) return;
    final uci = move.algebraic();
    final probe = UciGame()..rebuild(g.moves);
    if (!probe.play(uci)) return; // not legal on this device: ignore
    _run(() => _service.move(g.id, uci));
  }

  Future<void> _confirm(String title, String text, Future<DailyGame> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok == true) await _run(action);
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      appBar: AppBar(
        title: g == null
            ? const Text('Daily game')
            : Row(children: [
                if (_oppOnline != null)
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _oppOnline! ? Colors.green : Colors.grey,
                      boxShadow: [BoxShadow(color: (_oppOnline! ? Colors.green : Colors.grey).withAlpha(120), blurRadius: 4, spreadRadius: 1)],
                    ),
                  ),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('vs ${g.opponentName}', overflow: TextOverflow.ellipsis),
                    if (_oppOnline != null)
                      Text(
                        _oppOnline! ? 'Online' : 'Offline',
                        style: TextStyle(fontSize: 11.5, color: _oppOnline! ? Colors.green : Colors.grey, fontWeight: FontWeight.w600),
                      ),
                  ]),
                ),
              ]),
        actions: [
          if (g != null && g.isActive && !_inVoice)
            Tooltip(
              message: 'Voice chat',
              child: GestureDetector(
                onTap: _voiceBusy ? null : _joinVoice,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _voiceBusy
                      ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2))
                      : Image.asset(
                          AssetsManager.micIcon,
                          width: 26,
                          height: 26,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => Icon(
                            Icons.mic,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.flip), onPressed: () => setState(() => _manualFlip = !_manualFlip)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? Center(child: Text(_error ?? 'Game not found'))
              : SafeArea(
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    DailyTurnBanner(game: g),
                    if (_inVoice) _voiceBar(),
                    const SizedBox(height: 12),
                    LearnBoard(
                      state: _g.squares(g.iAmWhite ? 0 : 1), // already turned for MY colour; never the side to move
                      flipped: _flipped,
                      onMove: g.isActive && g.myTurn && !_busy ? _onMove : null,
                    ),
                    const SizedBox(height: 12),
                    ..._actions(g),
                    if (g.status == 'completed' && !g.inTournament) _rematchSection(g),
                    const SizedBox(height: 8),
                    Text(_moveText(g.moves), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
    );
  }

  Widget _drawOfferCard(DailyGame g) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Column(children: [
          Row(children: [
            Icon(Icons.handshake_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${g.opponentName} offers a draw',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _busy ? null : () => _run(() => _service.draw(g.id, 'decline')),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _busy ? null : () => _run(() => _service.draw(g.id, 'accept')),
                child: const Text('Accept draw'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _actions(DailyGame g) {
    final cs = Theme.of(context).colorScheme;
    final offeredToMe = g.drawOfferedBy != null && g.drawOfferedBy!.isNotEmpty && g.drawOfferedBy != g.myId;
    final offeredByMe = g.drawOfferedBy == g.myId;
    final active = g.isActive;
    return [
      if (active && offeredToMe) _drawOfferCard(g),
      Row(children: [
        Expanded(
          child: DailyActionButton(
            icon: Icons.chat_bubble_rounded,
            label: 'Chat',
            color: cs.primary,
            badge: _unread,
            onPressed: _openChat,
          ),
        ),
        if (active) ...[
          const SizedBox(width: 10),
          Expanded(
            child: DailyActionButton(
              icon: Icons.handshake_rounded,
              label: offeredByMe ? 'Offered' : 'Draw',
              color: const Color(0xFF1E88E5),
              onPressed: _busy || offeredByMe || offeredToMe
                  ? null
                  : () => _confirm('Offer a draw?', 'Your opponent can accept or decline.', () => _service.draw(g.id, 'offer')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DailyActionButton(
              icon: Icons.flag_rounded,
              label: 'Resign',
              color: cs.error,
              onPressed: _busy ? null : () => _confirm('Resign?', 'You lose this game.', () => _service.resign(g.id)),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
    ];
  }

  String _moveText(List<String> moves) {
    final b = StringBuffer();
    for (var i = 0; i < moves.length; i++) {
      if (i % 2 == 0) b.write('${i ~/ 2 + 1}. ');
      b.write('${moves[i]} ');
    }
    return b.toString();
  }
}
