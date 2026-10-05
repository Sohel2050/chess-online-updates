import 'package:flutter/material.dart';

class AudioControlsWidget extends StatelessWidget {
  final bool isInAudioRoom;
  final bool isMicrophoneEnabled;
  final bool isSpeakerMuted;
  final VoidCallback? onToggleMicrophone;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onLeaveAudio;
  final List<String> participants;

  const AudioControlsWidget({
    super.key,
    required this.isInAudioRoom,
    required this.isMicrophoneEnabled,
    required this.isSpeakerMuted,
    this.onToggleMicrophone,
    this.onToggleSpeaker,
    this.onLeaveAudio,
    this.participants = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (!isInAudioRoom) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Audio indicator
          // Container(
          //   padding: const EdgeInsets.all(4),
          //   decoration: BoxDecoration(
          //     color: Colors.green,
          //     borderRadius: BorderRadius.circular(4),
          //   ),
          //   child: Icon(
          //     Icons.radio_button_checked,
          //     size: 12,
          //     color: Colors.white,
          //   ),
          // ),
          // const SizedBox(width: 8),

          // // Participants count
          // Text(
          //   '${participants.length}',
          //   style: Theme.of(context).textTheme.bodySmall?.copyWith(
          //     fontWeight: FontWeight.w600,
          //     color: Theme.of(context).colorScheme.onPrimaryContainer,
          //   ),
          // ),
          // const SizedBox(width: 8),

          // Microphone control
          _buildControlButton(
            context,
            icon: isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            isEnabled: isMicrophoneEnabled,
            onPressed: onToggleMicrophone,
            tooltip:
                isMicrophoneEnabled ? 'Mute microphone' : 'Unmute microphone',
          ),
          const SizedBox(width: 4),

          // Speaker control
          _buildControlButton(
            context,
            icon: isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
            isEnabled: !isSpeakerMuted,
            onPressed: onToggleSpeaker,
            tooltip: isSpeakerMuted ? 'Unmute speaker' : 'Mute speaker',
          ),
          const SizedBox(width: 4),

          // Leave audio room
          _buildControlButton(
            context,
            icon: Icons.call_end,
            isEnabled: false,
            isDestructive: true,
            onPressed: onLeaveAudio,
            tooltip: 'Leave audio room',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required bool isEnabled,
    bool isDestructive = false,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    final backgroundColor =
        isDestructive
            ? Theme.of(context).colorScheme.error
            : isEnabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest;

    final iconColor =
        isDestructive
            ? Theme.of(context).colorScheme.onError
            : isEnabled
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
