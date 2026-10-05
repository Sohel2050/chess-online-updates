import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Last updated: February 2025',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 24),

            _SectionWidget(
              title: '1. Information We Collect',
              content:
              '''We collect information you provide directly to us, such as when you create an account, update your profile, or communicate with other users. This may include:

• Display name and profile information
• Email address (for account verification)
• Game statistics and match history
• Chat messages with other players
• Device information for app functionality''',
            ),

            _SectionWidget(
              title: '2. How We Use Your Information',
              content: '''We use the information we collect to:

• Provide and maintain our chess game service
• Match you with other players
• Track game statistics and rankings
• Enable communication between players
• Improve our app and user experience
• Send important updates about the service''',
            ),

            _SectionWidget(
              title: '3. Information Sharing',
              content:
              '''We do not sell, trade, or otherwise transfer your personal information to third parties. We may share information in the following circumstances:

• With other players during games (display name, rating, country flag)
• When required by law or to protect our rights
• With service providers who help us operate the app
• In case of a business transfer or merger''',
            ),

            _SectionWidget(
              title: '4. Data Security',
              content:
              '''We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure.''',
            ),

            _SectionWidget(
              title: '5. Data Retention',
              content:
              '''We retain your information for as long as your account is active or as needed to provide services. You may delete your account at any time, which will remove your personal information from our systems.''',
            ),

            _SectionWidget(
              title: '6. Children\'s Privacy',
              content:
              '''Our service is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you are a parent and believe your child has provided us with personal information, please contact us.''',
            ),

            _SectionWidget(
              title: '7. Your Rights',
              content: '''You have the right to:

• Access and update your personal information
• Delete your account and associated data
• Opt out of certain communications
• Request information about data we collect''',
            ),

            _SectionWidget(
              title: '8. Third-Party Services',
              content: '''Our app may use third-party services such as:

• Our own backend servers for account and game data
• Analytics services for app improvement
• Authentication services

These services have their own privacy policies governing their use of your information.''',
            ),

            _SectionWidget(
              title: '9. Changes to This Policy',
              content:
              '''We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy in the app. Changes are effective when posted.''',
            ),

            _SectionWidget(
              title: '10. Contact Us',
              content:
              '''If you have any questions about this privacy policy, please contact us at:
Email: support@kingcart.store
Website: www.kingcart.store

Please Visit Our Website For  privacy Policy Updates.
Thank You.
Chess Master 

''',
            ),

            SizedBox(height: 32),
            Text(
              'By using our chess app, you agree to the collection and use of information in accordance with this policy.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
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
