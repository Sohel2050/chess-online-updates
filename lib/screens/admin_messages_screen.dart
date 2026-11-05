import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_message_model.dart';
import '../services/message_service.dart';

final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

String _fmt(DateTime? d) => d == null ? '—' : _dateTimeFormat.format(d);

/// Admin: list of sent messages with read / click numbers + "send new".
class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final MessageService _service = MessageService();
  List<AdminMessage> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    try {
      final messages = await _service.adminGetMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages: $e';
        _loading = false;
      });
    }
  }

  Future<void> _compose() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminComposeMessageScreen()),
    );
    if (sent == true && mounted) _load(showSpinner: false);
  }

  Future<void> _openDetail(AdminMessage m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminMessageDetailScreen(messageId: m.id)),
    );
    if (mounted) _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.send),
        label: const Text('New message'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(showSpinner: false),
              child: _messages.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No messages sent yet')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _openDetail(m),
                            title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(_fmt(m.createdAt), style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 6),
                                Text(
                                  'Read ${m.readCount}/${m.recipients}  •  Clicked ${m.clickCount}/${m.recipients}',
                                ),
                                Text(
                                  m.isActive ? m.audienceLabel : '${m.audienceLabel} • Hidden',
                                  style: TextStyle(
                                    color: m.isActive ? Colors.green : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// Admin: write and send a new message.
class AdminComposeMessageScreen extends StatefulWidget {
  const AdminComposeMessageScreen({super.key});

  @override
  State<AdminComposeMessageScreen> createState() => _AdminComposeMessageScreenState();
}

class _AdminComposeMessageScreenState extends State<AdminComposeMessageScreen> {
  final MessageService _service = MessageService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _audience = 'all';
  bool _sending = false;
  bool _sendPush = true;
  bool _searching = false;
  List<MessageUserHit> _hits = [];
  MessageUserHit? _target;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type at least 2 letters of the name or email')),
      );
      return;
    }
    setState(() => _searching = true);
    try {
      final hits = await _service.adminSearchUsers(q);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
      });
      if (hits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }
    if (_audience == 'user' && _target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search and select a user first')),
      );
      return;
    }
    final who = _audience == 'user'
        ? _target!.label
        : _audience == 'registered'
        ? 'all registered users'
        : 'all users, including guests';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send message?'),
        content: Text('This will be visible to $who.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final push = await _service.adminSend(
        title: title,
        body: body,
        audience: _audience,
        targetUserId: _audience == 'user' ? _target?.id : null,
        sendPush: _sendPush,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            push == 'queued'
                ? 'Message sent. Push notifications are being delivered.'
                : push == 'not_configured'
                ? 'Message sent. Push is not set up on the server yet, users will see it in Messages.'
                : 'Message sent.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Widget> _buildUserPicker() {
    if (_target != null) {
      return [
        const SizedBox(height: 12),
        InputChip(
          avatar: const Icon(Icons.person),
          label: Text(_target!.isGuest ? '${_target!.label} (guest)' : _target!.label),
          onDeleted: _sending ? null : () => setState(() => _target = null),
        ),
      ];
    }
    return [
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'Search user by name or email',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                : const Icon(Icons.search),
          ),
        ],
      ),
      for (final hit in _hits)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(hit.displayName),
          subtitle: Text(hit.email ?? (hit.isGuest ? 'Guest' : '')),
          onTap: () => setState(() {
            _target = hit;
            _hits = [];
          }),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLength: 4000,
              minLines: 6,
              maxLines: 14,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _audience,
              decoration: const InputDecoration(labelText: 'Send to', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All users (including guests)')),
                DropdownMenuItem(value: 'registered', child: Text('Registered users only')),
                DropdownMenuItem(value: 'user', child: Text('One specific user')),
              ],
              onChanged: _sending ? null : (v) => setState(() => _audience = v ?? 'all'),
            ),
            if (_audience == 'user') ..._buildUserPicker(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Send push notification'),
              subtitle: const Text('Also notify phones, even when the app is closed'),
              value: _sendPush,
              onChanged: _sending ? null : (v) => setState(() => _sendPush = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending…' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin: one message with its numbers and the list of users who clicked / read it.
class AdminMessageDetailScreen extends StatefulWidget {
  final String messageId;

  const AdminMessageDetailScreen({super.key, required this.messageId});

  @override
  State<AdminMessageDetailScreen> createState() => _AdminMessageDetailScreenState();
}

class _AdminMessageDetailScreenState extends State<AdminMessageDetailScreen> {
  final MessageService _service = MessageService();
  AdminMessageDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await _service.adminGetMessage(widget.messageId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load: $e');
    }
  }

  Future<void> _toggleActive(AdminMessage m) async {
    try {
      await _service.adminSetActive(m.id, !m.isActive);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(AdminMessage m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('It disappears for all users and its read / click history is deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.adminDelete(m.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message details'),
        actions: [
          if (detail != null)
            IconButton(
              tooltip: detail.message.isActive ? 'Hide from users' : 'Show to users',
              icon: Icon(detail.message.isActive ? Icons.visibility_off : Icons.visibility),
              onPressed: () => _toggleActive(detail.message),
            ),
          if (detail != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(detail.message),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : detail == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _buildDetail(detail),
    );
  }

  Widget _buildDetail(AdminMessageDetail detail) {
    final m = detail.message;
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(m.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_fmt(m.createdAt)}  •  ${m.audienceLabel}${m.isActive ? '' : '  •  Hidden'}', style: textTheme.bodySmall),
          const SizedBox(height: 12),
          SelectableText(m.body),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statCard('Read', m.readCount, m.recipients, Icons.drafts)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Clicked', m.clickCount, m.recipients, Icons.touch_app)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Users (${detail.receipts.length})', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (detail.receipts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Nobody has opened this message yet.'),
            )
          else
            ...detail.receipts.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(r.readAt != null ? Icons.drafts : Icons.touch_app),
                title: Text(r.isGuest ? '${r.displayName} (guest)' : r.displayName),
                subtitle: Text(
                  '${r.email != null ? '${r.email}\n' : ''}Clicked: ${_fmt(r.clickedAt)}\nRead: ${_fmt(r.readAt)}',
                ),
                isThreeLine: true,
              ),
            ),
          if (detail.receipts.length >= 300)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Showing the 300 most recent users.'),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, int total, IconData icon) {
    final percent = total > 0 ? (value * 100 / total).round() : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text('$value / $total', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('$label ($percent%)'),
          ],
        ),
      ),
    );
  }
}
