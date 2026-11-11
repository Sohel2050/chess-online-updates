import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app Privacy Policy. The full text lives here (no external link).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String developerName = 'Albonik LLC';
  static const String developerWebsite = 'Albonik.com';
  static const String supportEmail = 'support@albonik.com';

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'Privacy question'},
    );
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email address copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: November 10, 2026',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Text(
              'This policy explains what information the chess app ("the app") '
              'collects, why, who sees it, and what choices you have. It covers '
              'every feature of the app: online games, chat, friends, clubs, '
              'tournaments, live watching, voice chat, puzzles, lessons, '
              'rankings, purchases and ads.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            const _SectionWidget(
              title: '1. Who we are',
              content:
                  'The app is developed and operated by $developerName '
                  '(\"we\", \"us\"), website $developerWebsite. We are the '
                  'controller of the personal data described here. Contact: '
                  '$supportEmail.',
            ),
            const _SectionWidget(
              title: '2. Age requirement',
              content:
                  'The app is for people aged 13 and over. You confirm this '
                  'when you start using the app or sign up. We do not knowingly '
                  'collect personal data from children under 13. If you believe '
                  'a child under 13 has an account, contact us and we will '
                  'delete it.',
            ),
            const _SectionWidget(
              title: '3. Information we collect',
              content:
                  '''Account: email address (if you sign up), display name, optional profile photo or built-in avatar, country (suggested from your IP address, you can change it), and a hashed password. Guest accounts have no email.

Gameplay: moves and results of your games, saved games, ratings, statistics, win/loss history, game reviews, puzzle and lesson progress, missions, streaks, badges, poll votes, leaderboard and ranking positions, tournament and club participation.

Social: friends and friend requests, blocked users, online status and last-seen time, chat messages you send (private chat, in-game chat and club chat), emoji reactions, and game invitations.

Live watching: if you switch on Public or Friends watching for a game, other people can watch it live and see your name, photo, country, rating, moves and clock. A shared watch link shows the same basic game information on a web page without signing in.

Voice chat: if you join an audio room, your voice is sent live to the other player through our voice provider (LiveKit). We do not record or store voice audio.

Reports and moderation: reports you send about a player or game, reports made about you, and the actions we take.

Photos: if you choose a profile photo, the picture you select is compressed and uploaded. The app does not browse your gallery or access any other photo.

Purchases: premium / remove-ads status. Payments are handled by Google Play (or the Apple App Store); we never see your card details.

Device and technical data: IP address, device model, operating system and app version, language, a push notification token, and an advertising ID (see Advertising).

Usage statistics: anonymous app events (for example which screens or features are used), sent to our own server and linked only to your account ID, not to your name, email, chat or game content. You can switch this off in Privacy Settings.

Crash reports: technical error details and your account ID are sent to Firebase Crashlytics (Google) so we can fix crashes.''',
            ),
            const _SectionWidget(
              title: '4. Permissions the app asks for',
              content:
                  '''Microphone: only for voice chat, and only after you join an audio room.

Nearby devices / Bluetooth connect: only to use a Bluetooth headset during voice chat.

Notifications: for game invites, friend requests, messages, rematch and other alerts. You can turn them off in the app or in your phone settings.

Photos / files: only through the system picker when you choose a profile photo.

Internet and network state: to play online and detect when you are offline.

Advertising ID: used by ad partners (see Advertising). You can reset or delete it in your device settings.''',
            ),
            const _SectionWidget(
              title: '5. How we use information',
              content:
                  'To create and run your account; match you with opponents and '
                  'run online games, tournaments and clubs; show ratings, '
                  'leaderboards and rankings; deliver chat, friends, live '
                  'watching and voice chat; save and replay your games; send '
                  'notifications; provide support; keep the community safe and '
                  'prevent cheating and abuse; fix crashes and improve the app; '
                  'process purchases; and show advertising that keeps the app '
                  'free.',
            ),
            const _SectionWidget(
              title: '6. Advertising',
              content:
                  '''The app shows ads through Unity LevelPlay, which mediates several ad networks (such as AppLovin, Chartboost, Meta Audience Network, InMobi, Mintegral, MobileFuse, Moloco, Ogury, PubMatic, Smaato, Unity Ads, Verve, Yandex and Liftoff/Vungle). These partners may collect your device advertising ID, IP address, approximate location derived from the IP address, and ad interaction data to deliver, measure and limit ads.

Some features can be unlocked by watching an ad (for example voice chat for one game). Users who buy premium / remove ads see no ads, and the administrator may turn ads off for certain features.

In regions that require it (EEA, UK and others) we ask for your consent before personalised advertising. You can change your choice any time in the app under Privacy Settings. If you decline, you may still see ads that are less relevant.''',
            ),
            const _SectionWidget(
              title: '7. Service providers we use',
              content:
                  '''Our own servers (hosting, database, game server, file storage) run the account, games, chat and rankings.

LiveKit: real-time voice chat.

Google Firebase: push notifications (Cloud Messaging) and crash reports (Crashlytics).

Unity LevelPlay and its ad networks: advertising.

Google Play / Apple App Store: purchases and subscriptions.

These providers process data only to provide their service and under their own privacy terms.''',
            ),
            const _SectionWidget(
              title: '8. What other people can see',
              content:
                  'Other players can see your display name, photo or avatar, '
                  'country, rating, statistics, badges, online status and your '
                  'games when you play them or when you allow watching. Chat '
                  'messages are visible to the person or club you send them to. '
                  'Your email address, password and device data are never shown '
                  'to other players.',
            ),
            const _SectionWidget(
              title: '9. Legal bases (EEA / UK)',
              content:
                  'We process data to perform our contract with you (running '
                  'your account and games), for our legitimate interests '
                  '(security, fraud and cheating prevention, crash fixing, '
                  'service improvement), to comply with the law, and with your '
                  'consent (personalised advertising, microphone and '
                  'notification permissions).',
            ),
            const _SectionWidget(
              title: '10. Sharing',
              content:
                  'We do not sell your personal data. We share data only with '
                  'the service providers in section 7, with other players as '
                  'described in section 8, when required by law or legal '
                  'process, to protect users, our rights or the security of the '
                  'app, and if the business is transferred to another company '
                  '(you would be informed).',
            ),
            const _SectionWidget(
              title: '11. Chat, community rules and moderation',
              content:
                  'Do not use chat, names, photos, voice or live watching for '
                  'harassment, hate, sexual content, threats, illegal activity '
                  'or cheating. You can block players and report games or '
                  'players. To handle reports we may review the reported game, '
                  'messages and account details. We may remove content, mute '
                  'or suspend accounts that break these rules.',
            ),
            const _SectionWidget(
              title: '12. International transfers',
              content:
                  'Our servers and partners may be located outside your '
                  'country, including outside the EEA/UK. Where required, we '
                  'rely on appropriate safeguards for such transfers.',
            ),
            const _SectionWidget(
              title: '13. Retention',
              content:
                  'We keep account data until you delete your account. Inactive '
                  'guest accounts are deleted automatically after a period of '
                  'inactivity. Chat messages sent during an online game are '
                  'deleted from our servers when that game ends. When you '
                  'delete your account we delete your profile, photo, saved '
                  'games, puzzle progress, votes, messages and friend '
                  'connections. We may keep limited records where the law '
                  'requires it or for abuse prevention (for example a ban '
                  'record).',
            ),
            const _SectionWidget(
              title: '14. Your rights and account deletion',
              content:
                  '''You can edit your profile and delete your account at any time in the app: Profile → Delete Account. You can also email $supportEmail to ask for deletion.

You can control: personalised ads and anonymous usage statistics (Privacy Settings), notifications (app or phone settings), microphone access (phone settings), who can watch your games (Live sheet), and who you play with (block list).

Depending on where you live (for example the EEA, UK or California) you may also have the right to access, correct, export or restrict the use of your data, to object to processing, to withdraw consent, and to complain to your data protection authority. Email $supportEmail to use these rights; we may need to verify it is really you.''',
            ),
            const _SectionWidget(
              title: '15. US state privacy notice (including California)',
              content:
                  'We do not sell personal information for money. Sharing '
                  'identifiers and ad interaction data with advertising '
                  'partners may count as \"sharing\" or \"targeted advertising\" '
                  'under some state laws. You can opt out by choosing '
                  '\"Don\'t allow\" in Privacy Settings in the app or by '
                  'emailing $supportEmail. We do not discriminate against you '
                  'for using your rights, and we do not knowingly sell or share '
                  'data of anyone under 16.',
            ),
            const _SectionWidget(
              title: '16. Security',
              content:
                  'Passwords are stored hashed, sign-in tokens are kept in '
                  'secure device storage, and data is sent over encrypted '
                  'connections (HTTPS). No system is perfectly secure, so we '
                  'cannot guarantee absolute security. Please use a strong '
                  'password and do not share it.',
            ),
            const _SectionWidget(
              title: '17. Changes to this policy',
              content:
                  'We may update this policy when the app or the law changes. '
                  'The new version is posted in the app with the date above. '
                  'If a change is important we will tell you in the app.',
            ),
            _SectionWidget(
              title: '18. Contact',
              content: '',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Developer: $developerName',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                  const Text(
                    'Website: $developerWebsite',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                  InkWell(
                    onTap: () => _emailSupport(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Email: $supportEmail',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final String title;
  final String content;
  final Widget? child;

  const _SectionWidget({required this.title, required this.content, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (content.isNotEmpty)
            Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (child != null) child!,
        ],
      ),
    );
  }
}
