import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final info = snap.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              Icon(Icons.extension, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  (info?.appName.isNotEmpty ?? false) ? info!.appName : 'Chess',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (info != null)
                Center(child: Text('Version ${info.version} (${info.buildNumber})', style: t.bodySmall)),
              const SizedBox(height: 24),
              Text(
                'A chess app for everyone: play online against real opponents, practise against the '
                'computer, play with a friend on one device, solve puzzles and review your games.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'We are a small team and we keep improving the app with your feedback. '
                'Thank you for playing!',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Contact Us'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
