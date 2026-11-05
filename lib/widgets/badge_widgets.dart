import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/badge_provider.dart';
import '../services/badge_service.dart';

IconData badgeIcon(String name) {
  switch (name) {
    case 'emoji_events':
      return Icons.emoji_events;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'extension':
      return Icons.extension;
    case 'emoji_emotions':
      return Icons.emoji_emotions;
    case 'military_tech':
      return Icons.military_tech;
    default:
      return Icons.workspace_premium;
  }
}

Color _groupColor(String group) {
  switch (group) {
    case 'wins':
      return const Color(0xFFF59E0B);
    case 'streak':
      return const Color(0xFFF97316);
    case 'puzzles':
      return const Color(0xFF3B82F6);
    case 'emoji':
      return const Color(0xFFEC4899);
    default:
      return const Color(0xFF22C55E);
  }
}

/// One round badge: coloured when earned, grey with a progress ring when not.
class BadgeTile extends StatelessWidget {
  final BadgeInfo badge;
  const BadgeTile({super.key, required this.badge});

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(badgeIcon(badge.icon), color: badge.earned ? _groupColor(badge.group) : Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(badge.title)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(badge.desc),
            const SizedBox(height: 10),
            if (badge.earned)
              Text(
                badge.earnedAt == null
                    ? 'Earned'
                    : 'Earned on ${badge.earnedAt!.toLocal().toString().substring(0, 10)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            else
              Text('Progress: ${badge.progress} / ${badge.target}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = badge.earned ? _groupColor(badge.group) : Colors.grey;
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: badge.earned ? 1 : badge.fraction,
                strokeWidth: 3,
                color: color,
                backgroundColor: color.withValues(alpha: 0.18),
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: badge.earned ? 0.18 : 0.08)),
              child: Icon(badgeIcon(badge.icon), color: color.withValues(alpha: badge.earned ? 1 : 0.55), size: 26),
            ),
            if (badge.isNew)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(
            badge.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: badge.earned ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// "Badges  3 / 12" + the grid, for the profile screen.
class BadgesSection extends StatelessWidget {
  const BadgesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BadgeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Badges', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (p.loaded)
            Text('${p.earnedCount} / ${p.badges.length}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 10),
        if (!p.loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 6,
            childAspectRatio: 0.78,
            children: [for (final b in p.badges) BadgeTile(badge: b)],
          ),
      ],
    );
  }
}

Future<void> showNewBadgesDialog(BuildContext context, List<BadgeInfo> fresh) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(fresh.length == 1 ? '\u{1F3C5} New badge!' : '\u{1F3C5} ${fresh.length} new badges!'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in fresh)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(badgeIcon(b.icon), color: _groupColor(b.group), size: 34),
                title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(b.desc),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nice!'))],
    ),
  );
}
