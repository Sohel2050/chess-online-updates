import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String contactEmail = 'support@albonik.com';
  static const String website = 'albonik.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Last updated: October 2026',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: 24),
            _SectionWidget(
              title: '1. Who we are',
              content:
                  'This chess app ("the app") is published by Albonik ("we", "us"). '
                  'You can contact us at $contactEmail.',
            ),
            _SectionWidget(
              title: '2. Age requirement',
              content:
                  'The app is for people aged 13 and over. We do not knowingly '
                  'collect personal data from children under 13. If you believe '
                  'a child under 13 has an account, contact us and we will delete it.',
            ),
            _SectionWidget(
              title: '3. Data we collect',
              content:
                  '''Account data: email address (if you sign up), display name, profile photo (optional), country, and a hashed password. Guest accounts store only the data below, without an email.

Game data: ratings, statistics, achievements, saved games, puzzle progress, poll votes, friends, friend requests, blocked users, and online status / last seen time.

Messages: chat messages you send to other players.

Voice: if you join an audio room, your voice is transmitted live to the other player through our voice provider (LiveKit). We do not record it.

Purchases: purchase status for removing ads / premium is handled by Google Play. We do not receive your payment card details.

Technical data: IP address and basic device information are processed by our server and by our advertising partners. Advertising partners may also use your device advertising ID.''',
            ),
            _SectionWidget(
              title: '4. How we use data',
              content:
                  'To run your account and online games, show leaderboards and '
                  'rankings, enable chat and friends, provide support, prevent '
                  'abuse, process purchases, and show advertising that keeps the '
                  'app free.',
            ),
            _SectionWidget(
              title: '5. Advertising',
              content:
                  '''The app shows ads through Unity LevelPlay, which mediates several ad networks (such as AppLovin, Chartboost, Meta Audience Network, InMobi, Mintegral, MobileFuse, Moloco, Ogury, PubMatic, Smaato, Unity Ads, Verve, Yandex and Liftoff/Vungle). These partners may collect your device advertising ID, IP address and ad interaction data to deliver and measure ads.

In regions that require it (EEA, UK and others) we ask for your consent before personalised advertising. You can change your choice any time in the app under Privacy Settings. If you decline, you may still see ads that are less relevant. You can also reset your advertising ID in your device settings. Users who buy the "remove ads" option see no ads.''',
            ),
            _SectionWidget(
              title: '6. Legal bases (EEA / UK)',
              content:
                  'We process data to perform our contract with you (running your '
                  'account and games), for our legitimate interests (security, '
                  'fraud prevention, service improvement), to comply with the '
                  'law, and with your consent (personalised advertising).',
            ),
            _SectionWidget(
              title: '7. Sharing',
              content:
                  'We do not sell your personal data. We share data only with '
                  'service providers that help run the app (hosting, voice, '
                  'advertising and payment providers), with other players as '
                  'part of the game (your display name, photo, country, rating '
                  'and online status), when required by law, or to protect users.',
            ),
            _SectionWidget(
              title: '8. International transfers',
              content:
                  'Our servers and partners may be located outside your country, '
                  'including outside the EEA/UK. Where required, we rely on '
                  'appropriate safeguards for such transfers.',
            ),
            _SectionWidget(
              title: '9. Retention',
              content:
                  'We keep account data until you delete your account. Inactive '
                  'guest accounts are deleted automatically after a period of '
                  'inactivity. When you delete your account we delete your '
                  'profile, photo, saved games, puzzle progress, votes, chat '
                  'messages and friend connections.',
            ),
            _SectionWidget(
              title: '10. Your rights and account deletion',
              content:
                  '''You can edit your profile and delete your account at any time in the app: Profile → Delete Account. You can also request deletion on our website or by emailing $contactEmail.

Depending on where you live (for example the EEA, UK or California) you may also have the right to access, correct, export or restrict the use of your data, to object to processing, to withdraw consent, and to complain to your data protection authority. Contact us to use these rights.''',
            ),
            _SectionWidget(
              title: '11. US state privacy notice (including California)',
              content:
                  'We do not sell personal information for money. Sharing '
                  'identifiers and ad interaction data with advertising '
                  'partners may count as "sharing" or "targeted advertising" '
                  'under some state laws. You can opt out by choosing '
                  '"Don\'t allow" in Privacy Settings in the app or by '
                  'emailing $contactEmail. We do not discriminate against you '
                  'for using your rights, and we do not knowingly sell or '
                  'share data of anyone under 16.',
            ),
            _SectionWidget(
              title: '12. Community rules',
              content:
                  'Do not use chat, names or photos for harassment, hate, '
                  'sexual content, illegal activity or cheating. You can '
                  'block other players. We may remove content or suspend '
                  'accounts that break these rules.',
            ),
            _SectionWidget(
              title: '13. Security',
              content:
                  'Passwords are stored hashed and data is sent over encrypted '
                  'connections (HTTPS). No system is perfectly secure, so we '
                  'cannot guarantee absolute security.',
            ),
            _SectionWidget(
              title: '14. Changes',
              content:
                  'We may update this policy. The new version is posted in the '
                  'app and on our website, with the date above.',
            ),
            _SectionWidget(
              title: '15. Contact',
              content: 'Email: $contactEmail\nWebsite: $website',
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final String title;
  final String content;

  const _SectionWidget({required this.title, required this.content});

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
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
