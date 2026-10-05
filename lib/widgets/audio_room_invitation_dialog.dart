import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';

enum AudioRoomAction { join, reject }

class AudioRoomInvitationDialog extends StatelessWidget {
  final ChessUser invitingUser;
  final VoidCallback? onJoin;
  final VoidCallback? onReject;

  const AudioRoomInvitationDialog({
    super.key,
    required this.invitingUser,
    this.onJoin,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon and title
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            Icons.mic,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          'Audio Room Invitation',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // User invitation info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ProfileImageWidget(
                imageUrl: invitingUser.photoUrl,
                countryCode: invitingUser.countryCode,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitingUser.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'wants to start voice chat',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.volume_up,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Description
        Text(
          'Join the audio room to talk with your opponent during the game.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Features list
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              _buildFeatureRow(
                context,
                Icons.mic,
                'Real-time voice communication',
              ),
              const SizedBox(height: 4),
              _buildFeatureRow(context, Icons.volume_up, 'High-quality audio'),
              const SizedBox(height: 4),
              _buildFeatureRow(
                context,
                Icons.settings_voice,
                'Mute/unmute controls',
              ),
            ],
          ),
        ),
      ],
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

  static Future<AudioRoomAction?> show({
    required BuildContext context,
    required ChessUser invitingUser,
  }) {
    return showDialog<AudioRoomAction>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            contentPadding: const EdgeInsets.all(24),
            content: AudioRoomInvitationDialog(invitingUser: invitingUser),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(context).pop(AudioRoomAction.reject),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(context).pop(AudioRoomAction.join),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Join Audio'),
              ),
            ],
          ),
    );
  }
}
