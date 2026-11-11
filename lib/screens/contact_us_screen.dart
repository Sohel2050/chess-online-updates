import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_service.dart';

/// Contact Us: support e-mail on top, WhatsApp "Live chat" below it.
/// The admin panel (Contact Us card) can change the e-mail and show / hide Live chat.
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const Color _waGreen = Color(0xFF25D366);
  late Future<ContactConfig> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService().getContactConfig();
  }

  Future<void> _open(Uri uri) async {
    bool ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the app. Please try again.')),
      );
    }
  }

  void _mail(String email) {
    final subject = Uri.encodeComponent('Chess app support');
    _open(Uri.parse('mailto:$email?subject=$subject'));
  }

  void _liveChat(String digits) {
    final text = Uri.encodeComponent('Hello, I need help with the Chess app.');
    _open(Uri.parse('https://wa.me/$digits?text=$text'));
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: FutureBuilder<ContactConfig>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final cfg = snap.data ?? const ContactConfig();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _hero(context),
              const SizedBox(height: 20),
              if (cfg.hasEmail)
                _contactCard(
                  context,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.mail_rounded,
                  title: 'Email us',
                  subtitle: cfg.email,
                  note: 'Best for questions, account help and privacy requests',
                  onTap: () => _mail(cfg.email),
                  onLongPress: () => _copy(cfg.email),
                  actionLabel: 'Send email',
                ),
              if (cfg.hasEmail && cfg.hasWhatsapp) const SizedBox(height: 14),
              if (cfg.hasWhatsapp)
                _contactCard(
                  context,
                  color: _waGreen,
                  icon: Icons.forum_rounded,
                  title: 'Live chat',
                  subtitle: 'Chat with us on WhatsApp',
                  note: '+${cfg.whatsappDigits}',
                  onTap: () => _liveChat(cfg.whatsappDigits),
                  onLongPress: () => _copy('+${cfg.whatsappDigits}'),
                  actionLabel: 'Start chat',
                ),
              if (!cfg.hasEmail && !cfg.hasWhatsapp)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Contact options are not available right now. Please check back later.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Albonik LLC  •  Albonik.com',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.65)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We are here to help',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Questions, feedback or a problem with the app? Get in touch.',
                  style: TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String note,
    required String actionLabel,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: tt.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(note, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
