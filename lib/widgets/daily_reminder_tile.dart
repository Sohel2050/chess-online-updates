import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/notification_settings_service.dart';

/// Settings switch for the daily reminder push. Hidden for guests by the caller.
class DailyReminderTile extends StatefulWidget {
  const DailyReminderTile({super.key});

  @override
  State<DailyReminderTile> createState() => _DailyReminderTileState();
}

class _DailyReminderTileState extends State<DailyReminderTile> {
  final NotificationSettingsService _service = NotificationSettingsService();
  bool _enabled = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await _service.getDailyReminders();
    if (!mounted) return;
    setState(() {
      _enabled = value ?? true;
      _loaded = value != null;
    });
  }

  Future<void> _toggle(bool value) async {
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _saving = true;
    });
    final ok = await _service.setDailyReminders(value);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _enabled = previous;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check your connection and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: const Text('Daily Reminders'),
      subtitle: const Text('At most one a day: today\'s puzzle, or a streak about to end'),
      value: _enabled,
      onChanged: (_loaded && !_saving) ? _toggle : null,
    );
  }
}
