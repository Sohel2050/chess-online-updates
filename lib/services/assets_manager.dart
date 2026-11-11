class AssetsManager {
  static String images = 'assets/images';
  static String icons = 'assets/icon';

  static String appLogo = '$icons/foreground.png';
  static String micIcon = '$icons/mic_icon.png';
  static String aiThinking = '$icons/ai_thinking.png';
  static String undoButton = '$icons/undo_btn.png';
  static String appIcon = '$icons/icon2.png';

  static String userIcon = '$images/user_icon.png';
  // Old built-in avatars. Kept ONLY so users who already picked one keep seeing
  // their photo; they are no longer offered in the picker.
  static String boyAvatar = '$images/boy_1.jpg';
  static String girlAvatar = '$images/girl_1.jpg';
  static String manAvatar = '$images/man_1.jpg';
  static String womanAvatar = '$images/woman_1.jpg';

  // Built-in avatars offered to every user (guest and registered).
  // The 12 current avatars are avatar_new_01 ... avatar_new_12.
  static String _newAvatar(int n) => '$images/avatar_new_${n.toString().padLeft(2, '0')}.jpg';

  // Bearded man with glasses: the default for NEW users (first in the list).
  static String defaultAvatar = _newAvatar(1);

  static List<String> avatars = List<String>.generate(12, (i) => _newAvatar(i + 1));

  // OLD avatar files (avatar_1.png ... avatar_8.png) are kept in assets only so
  // that existing users who already chose one keep seeing it. They are no
  // longer offered in the picker.
  static String avatar1 = '$images/avatar_1.png';
  static String avatar2 = '$images/avatar_2.png';
  static String avatar3 = '$images/avatar_3.png';
  static String avatar4 = '$images/avatar_4.png';
  static String avatar5 = '$images/avatar_5.png';
  static String avatar6 = '$images/avatar_6.png';
  static String avatar7 = '$images/avatar_7.png';
  static String avatar8 = '$images/avatar_8.png';

}
