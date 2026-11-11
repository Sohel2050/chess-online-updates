import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/monetization_service.dart';

enum AudioAccessAction { premium, watchAd, cancel }

/// Voice-chat unlock sheet.
///
/// Only shown when the admin "voice chat ad gate" is ON and the user would
/// normally see ads (see `_hasAudioAccess()` in game_screen.dart). When the
/// admin turns the gate OFF, or the user is premium, this dialog never opens.
///
/// The single action is "Watch a short ad". The Premium upsell is hidden by
/// default ([showPremiumOption] = false); pass `true` to bring it back.
class AudioAccessDialog extends StatefulWidget {
  final bool showPremiumOption;

  const AudioAccessDialog({super.key, this.showPremiumOption = false});

  @override
  State<AudioAccessDialog> createState() => _AudioAccessDialogState();

  static Future<AudioAccessAction?> show({
    required BuildContext context,
    bool showPremiumOption = false,
  }) {
    return showDialog<AudioAccessAction>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: AudioAccessDialog(showPremiumOption: showPremiumOption),
      ),
    );
  }
}

class _AudioAccessDialogState extends State<AudioAccessDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoadingAd = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(cs),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    Text(
                      'Talk while you play',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Watch one short ad to unlock voice chat with your opponent for this game.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _featureChip(cs, tt, Icons.mic_rounded, 'Live\nvoice'),
                        const SizedBox(width: 10),
                        _featureChip(
                          cs,
                          tt,
                          Icons.graphic_eq_rounded,
                          'Clear\naudio',
                        ),
                        const SizedBox(width: 10),
                        _featureChip(
                          cs,
                          tt,
                          Icons.volume_off_rounded,
                          'Mute\nanytime',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildWatchAdButton(cs, tt),
                    if (widget.showPremiumOption) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isLoadingAd
                            ? null
                            : () => Navigator.of(
                                context,
                              ).pop(AudioAccessAction.premium),
                        icon: const Icon(Icons.star_rounded, size: 18),
                        label: const Text('Go Premium instead'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _isLoadingAd
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(AudioAccessAction.cancel),
                      child: const Text('Maybe later'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.6)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft pulsing rings behind the mic.
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (final delay in const [0.0, 0.5])
                    _ring(((_pulse.value + delay) % 1.0)),
                ],
              );
            },
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.mic_rounded, size: 40, color: cs.primary),
          ),
        ],
      ),
    );
  }

  Widget _ring(double t) {
    final size = 76 + 90 * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: (1 - t) * 0.45),
          width: 2,
        ),
      ),
    );
  }

  Widget _featureChip(
    ColorScheme cs,
    TextTheme tt,
    IconData icon,
    String label,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: cs.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchAdButton(ColorScheme cs, TextTheme tt) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isLoadingAd ? null : _handleWatchAd,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingAd)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              const Icon(Icons.play_circle_fill_rounded, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingAd ? 'Loading ad...' : 'Watch ad & unlock',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimary,
                  ),
                ),
                Text(
                  'Voice chat for 1 game',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleWatchAd() async {
    setState(() => _isLoadingAd = true);

    try {
      // Interstitial via the unified monetization service. Access is granted
      // as soon as the ad is closed.
      await MonetizationService.showInterstitialAd(
        context: context,
        gameOver: false,
        onAdClosed: () {
          if (mounted) {
            Navigator.of(context).pop(AudioAccessAction.watchAd);
          }
        },
        onAdFailedToLoad: () {
          if (mounted) {
            setState(() => _isLoadingAd = false);
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
        setState(() => _isLoadingAd = false);
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
