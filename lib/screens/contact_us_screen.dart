import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_service.dart';

/// Contact Us: support email (mailto) and WhatsApp. Both are controlled from the admin panel:
/// the email address is typed there, WhatsApp can be switched on/off there.
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
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

  void _whatsapp(String digits) => _open(Uri.parse('https://wa.me/$digits'));

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
          if (!cfg.hasEmail && !cfg.hasWhatsapp) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Contact options are not available right now. Please check back later.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'We would love to hear from you. Questions, feedback or problems with the app - get in touch.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (cfg.hasEmail)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(cfg.email),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _mail(cfg.email),
                  ),
                ),
              if (cfg.hasWhatsapp)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.chat_outlined, color: Colors.green),
                    title: const Text('WhatsApp'),
                    subtitle: Text('+${cfg.whatsappDigits}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _whatsapp(cfg.whatsappDigits),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
