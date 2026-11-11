import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Future<void> _openWebsite(BuildContext context) async {
    bool ok = false;
    try {
      ok = await launchUrl(
        Uri.parse('https://albonik.com'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final info = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // ---- Hero ----
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(cs.primary, Colors.white, 0.08)!,
                        Color.lerp(cs.primary, Colors.black, 0.55)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Soft decorative circles + chess pieces behind the logo
                      Positioned(
                        top: -50,
                        right: -40,
                        child: _GlowCircle(size: 170, alpha: 0.10),
                      ),
                      Positioned(
                        bottom: -60,
                        left: -50,
                        child: _GlowCircle(size: 190, alpha: 0.08),
                      ),
                      Positioned(
                        top: 18,
                        left: 22,
                        child: Icon(Icons.extension_rounded, size: 30, color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      Positioned(
                        bottom: 20,
                        right: 24,
                        child: Icon(Icons.grid_view_rounded, size: 34, color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 26),
                        child: Column(
                          children: [
                            // Logo: glowing halo + white ring + golden accent
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFFFFD54F).withValues(alpha: 0.55),
                                    const Color(0xFFFFD54F).withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 112,
                                height: 112,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFFFB300), width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset('assets/icon/icon2.png', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (info?.appName.isNotEmpty ?? false) ? info!.appName : 'Chess Online',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (info != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  'Version ${info.version} (${info.buildNumber})',
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                ),
                              ),
                            const SizedBox(height: 14),
                            const Text(
                              'A chess app for everyone. Play, learn and enjoy the game.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ---- What you can do ----
              Text('What you can do', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: const [
                  _Feature(Icons.public_rounded, 'Play online'),
                  _Feature(Icons.smart_toy_rounded, 'Vs computer'),
                  _Feature(Icons.people_alt_rounded, 'Friends'),
                  _Feature(Icons.extension_rounded, 'Puzzles'),
                  _Feature(Icons.school_rounded, 'Lessons'),
                  _Feature(Icons.mic_rounded, 'Voice chat'),
                ],
              ),
              const SizedBox(height: 22),

              // ---- Developer ----
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.business_rounded, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Developed by', style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                            Text('Albonik LLC', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'We are a small team and we keep improving the app with your feedback. '
                      'Thank you for playing!',
                      style: t.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.language_rounded,
                      text: 'Albonik.com',
                      onTap: () => _openWebsite(context),
                    ),
                    const _InfoRow(icon: Icons.mail_outline_rounded, text: 'support@albonik.com'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Links ----
              _LinkTile(
                icon: Icons.support_agent_rounded,
                title: 'Contact Us',
                subtitle: 'Email or live chat',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _LinkTile(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  '© ${DateTime.now().year} Albonik LLC. All rights reserved.',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: cs.primary),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: onTap != null ? cs.primary : null,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final double alpha;
  const _GlowCircle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}
