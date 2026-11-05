import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mission_provider.dart';
import '../providers/streak_provider.dart';
import '../services/mission_service.dart';
import '../widgets/level_card.dart';
import '../providers/badge_provider.dart';

/// Daily streak + the 3 daily missions. Reward (XP) is claimed with a button.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  static const _green = Color(0xFF22C55E);
  static const _orange = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MissionProvider>().refresh();
      context.read<StreakProvider>().refresh();
      context.read<BadgeProvider>().refreshAndCelebrate(context);
    });
  }

  IconData _icon(String id) {
    switch (id) {
      case 'game':
        return Icons.sports_esports;
      case 'puzzle':
        return Icons.extension;
      default:
        return Icons.emoji_emotions;
    }
  }

  Future<void> _claim(Mission m) async {
    final provider = context.read<MissionProvider>();
    final before = provider.level;
    final ok = await provider.claim(m.id);
    if (!mounted) return;
    final after = provider.level;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '+${m.xp} XP!' : 'Could not claim the reward. Try again.'),
        backgroundColor: ok ? _green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    if (ok && after > before) {
      await showLevelUpDialog(context, before, after);
    }
  }

  Widget _streakCard(BuildContext context) {
    final streak = context.watch<StreakProvider>().info;
    final current = streak?.current ?? 0;
    final color = current == 0
        ? Colors.grey
        : (streak!.atRisk ? const Color(0xFFF59E0B) : _orange);
    final String line;
    if (streak == null) {
      line = 'Loading...';
    } else if (current == 0) {
      line = 'Play a game or solve a puzzle today to start your streak!';
    } else if (streak.atRisk) {
      line = 'Play a game or solve a puzzle today to keep it going!';
    } else {
      line = 'Done for today. Come back tomorrow!';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text('\u{1F525}', style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$current day streak',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(line, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                if (streak != null && streak.best > 0)
                  Text(
                    'Best: ${streak.best}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _missionCard(Mission m, bool busy) {
    final done = m.completed;
    final accent = m.claimed ? Colors.grey : (done ? _green : Colors.white70);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (done && !m.claimed ? _green : Colors.white24)),
      ),
      child: Row(
        children: [
          Icon(m.claimed ? Icons.check_circle : _icon(m.id), color: accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: m.claimed ? 0.5 : 1),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (m.progress / m.target).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: m.claimed ? Colors.grey : _green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${m.progress}/${m.target}  -  ${m.xp} XP',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (m.claimed)
            Text('Claimed', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12))
          else if (m.canClaim)
            ElevatedButton(
              onPressed: busy ? null : () => _claim(m),
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.black),
              child: const Text('Claim'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissionProvider>();
    final state = provider.state;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F0D),
        elevation: 0,
        title: const Text('Daily Missions'),
        actions: [
          if (state != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Lv ${provider.level} \u00B7 ${state.xp} XP',
                  style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<MissionProvider>().refresh();
          if (context.mounted) await context.read<StreakProvider>().refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _streakCard(context),
            const SizedBox(height: 18),
            Text(
              "Today's missions",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (state == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else
              for (final m in state.missions) _missionCard(m, provider.claiming),
            const SizedBox(height: 6),
            Text(
              'Emoji reactions are sent during online games. New missions every day.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
