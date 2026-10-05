import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';

class AvatarSelectionDialog extends StatelessWidget {
  const AvatarSelectionDialog({super.key});

  static Future<String?> show({required BuildContext context}) {
    return AnimatedDialog.show<String>(
      context: context,
      title: 'Choose Avatar',
      scrollable: true,
      child: const AvatarSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: AssetsManager.avatars.length,
      itemBuilder: (context, index) {
        final avatar = AssetsManager.avatars[index];
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(avatar),
          child: CircleAvatar(backgroundImage: AssetImage(avatar)),
        );
      },
    );
  }
}
