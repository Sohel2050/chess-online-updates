import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/monetization_service.dart';

enum AudioAccessAction { premium, watchAd, cancel }

class AudioAccessDialog extends StatefulWidget {
  const AudioAccessDialog({super.key});

  @override
  State<AudioAccessDialog> createState() => _AudioAccessDialogState();

  static Future<AudioAccessAction?> show({required BuildContext context}) {
    return showDialog<AudioAccessAction>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: const AudioAccessDialog(),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(AudioAccessAction.cancel),
            child: const Text('Later'),
          ),
        ],
      ),
    );
  }
}

class _AudioAccessDialogState extends State<AudioAccessDialog> {
  bool _isLoadingAd = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade300, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(Icons.mic, size: 48, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          'Audio Room Access',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Choose how to unlock voice chat',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Premium option
        _buildOptionCard(
          context,
          icon: Icons.star,
          title: 'Upgrade to Premium',
          subtitle: 'Unlimited access to all features',
          color: Colors.orange,
          onTap: () => Navigator.of(context).pop(AudioAccessAction.premium),
        ),
        const SizedBox(height: 12),

        // Watch ad option
        _buildOptionCard(
          context,
          icon: Icons.play_circle_fill,
          title: 'Watch Ad for Access',
          subtitle: _isLoadingAd
              ? 'Loading ad...'
              : 'Get 1 game of audio room access',
          color: Colors.blue,
          onTap: _isLoadingAd ? null : _handleWatchAd,
          isLoading: _isLoadingAd,
        ),
        const SizedBox(height: 16),

        // Features list
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              _buildFeatureRow(context, Icons.mic, 'Real-time voice chat'),
              const SizedBox(height: 4),
              _buildFeatureRow(
                context,
                Icons.volume_up,
                'Crystal clear audio quality',
              ),
              const SizedBox(height: 4),
              _buildFeatureRow(
                context,
                Icons.settings_voice,
                'Advanced audio controls',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  void _handleWatchAd() async {
    setState(() {
      _isLoadingAd = true;
    });

    try {
      // Load and show interstitial ad using unified monetization service
      // User gets audio access immediately after watching the interstitial ad
      await MonetizationService.showInterstitialAd(
        context: context,
        onAdClosed: () {
          // Ad was closed, grant access and close dialog
          if (mounted) {
            Navigator.of(context).pop(AudioAccessAction.watchAd);
          }
        },
        onAdFailedToLoad: () {
          // Ad failed to load, show error
          if (mounted) {
            setState(() {
              _isLoadingAd = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to load ad. Please try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAd = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
