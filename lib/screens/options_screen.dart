import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/settings_provider.dart';
import 'package:flutter_chess_app/screens/privacy_policy_screen.dart';
import 'package:flutter_chess_app/screens/privacy_settings_screen.dart';
import 'package:flutter_chess_app/screens/community_poll_screen.dart';
import 'package:flutter_chess_app/screens/messages_screen.dart';
import 'package:flutter_chess_app/screens/account_status_screen.dart';
import 'package:flutter_chess_app/widgets/daily_reminder_tile.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../models/user_model.dart';
import '../providers/mission_provider.dart';
import '../services/sound_service.dart';
import '../utils/chess_styles.dart';
import '../utils/levels.dart';
import 'credits_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';

class OptionsScreen extends StatefulWidget {
  final ChessUser user;

  const OptionsScreen({super.key, required this.user});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  // Draft choices: previewed live, saved only when Apply is pressed.
  late String _boardId;
  late String _pieceId;
  Color? _white;
  Color? _black;

  int _level = 1;
  String _savedBoardId = ''; // what is applied right now (refreshed on every build)
  String _savedPieceId = '';

  @override
  void initState() {
    super.initState();
    _loadFrom(context.read<SettingsProvider>());
  }

  void _loadFrom(SettingsProvider s) {
    _boardId = boardStyleOfTheme(s.boardTheme).id;
    _pieceId = s.pieceSet;
    _white = s.whitePieceColor;
    _black = s.blackPieceColor;
  }

  bool _isDirty(SettingsProvider s) =>
      _boardId != boardStyleOfTheme(s.boardTheme).id ||
      _pieceId != s.pieceSet ||
      _white?.toARGB32() != s.whitePieceColor?.toARGB32() ||
      _black?.toARGB32() != s.blackPieceColor?.toARGB32();

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    _level = context.watch<MissionProvider>().level;
    _savedBoardId = boardStyleOfTheme(settingsProvider.boardTheme).id;
    _savedPieceId = settingsProvider.pieceSet;
    final dirty = _isDirty(settingsProvider);

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final choice = await _askApply(context);
        if (!mounted) return;
        if (choice == 'apply') {
          settingsProvider.applyAppearance(
            boardTheme: boardStyleById(_boardId).theme,
            pieceSet: _pieceId,
            white: _white,
            black: _black,
          );
          nav.pop();
        } else if (choice == 'discard') {
          nav.pop();
        }
        // 'keep' or dialog dismissed: stay on the screen.
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: ListView(
        children: [
          _buildSectionHeader('Appearance'),
          SwitchListTile.adaptive(
            secondary: Icon(settingsProvider.darkMode ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Night Mode'),
            subtitle: Text(settingsProvider.darkMode ? 'Dark theme is on' : 'Light theme is on'),
            value: settingsProvider.darkMode,
            onChanged: (value) => settingsProvider.setDarkMode(value),
          ),
          _buildLivePreview(context, settingsProvider),
          _buildSubHeader(context, 'Board Theme'),
          _buildBoardThemePicker(context, settingsProvider),
          _buildSubHeader(context, 'Piece Set'),
          _buildPieceSetPicker(context, settingsProvider),
          _buildSubHeader(context, 'Piece Colors'),
          _buildPieceColors(context, settingsProvider),
          _buildApplyBar(context, settingsProvider),
          _buildToggleSwitch(
            title: 'Show Board Labels',
            value: settingsProvider.showLabels,
            onChanged: (value) => settingsProvider.setShowLabels(value),
          ),
          _buildToggleSwitch(
            title: 'Animate Pieces',
            value: settingsProvider.animatePieces,
            onChanged: (value) => settingsProvider.setAnimatePieces(value),
          ),
          _buildToggleSwitch(
            title: 'Confirm Moves (tap to confirm before playing)',
            value: settingsProvider.confirmMoves,
            onChanged: (value) => settingsProvider.setConfirmMoves(value),
          ),
          _buildToggleSwitch(
            title: 'Rating Based Search',
            value: settingsProvider.ratingBasedSearch,
            onChanged: (value) => settingsProvider.setRatingBasedSearch(value),
          ),
          const Divider(),
          _buildSectionHeader('Sound & Feedback'),
          SwitchListTile.adaptive(
            secondary: Icon(settingsProvider.soundEnabled ? Icons.volume_up : Icons.volume_off),
            title: const Text('Sound Effects'),
            subtitle: const Text('Moves, captures, check, timer and chat sounds'),
            value: settingsProvider.soundEnabled,
            onChanged: (value) {
              settingsProvider.setSoundEnabled(value);
              if (value) SoundService.instance.play(SoundEffect.move); // quick test sound
            },
          ),
          ListTile(
            enabled: settingsProvider.soundEnabled,
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Volume'),
            subtitle: Slider(
              value: settingsProvider.soundVolume,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(settingsProvider.soundVolume * 100).round()}%',
              onChanged: settingsProvider.soundEnabled
                  ? (value) => settingsProvider.setSoundVolume(value)
                  : null,
              onChangeEnd: (_) => SoundService.instance.play(SoundEffect.capture), // test sound
            ),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibration'),
            subtitle: const Text('A small tap when a move is made'),
            value: settingsProvider.hapticsEnabled,
            onChanged: (value) => settingsProvider.setHapticsEnabled(value),
          ),
          const Divider(),
          _buildSectionHeader('Accessibility'),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.visibility),
            title: const Text('Color-Blind Mode'),
            subtitle: const Text(
                'High-contrast blue board and blue/orange highlights that stay clear with red-green color blindness. Overrides the board theme while on.'),
            value: settingsProvider.colorBlindMode,
            onChanged: (value) => settingsProvider.setColorBlindMode(value),
          ),
          const Divider(),
          _buildSectionHeader('Community & Sharing'),
          _buildListTile(
            title: 'Share the App',
            icon: Icons.share,
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              final packageName = info.packageName;
              final appName = info.appName;

              final appLink =
                  'https://play.google.com/store/apps/details?id=$packageName';

              log('App Link: $appLink');
              log('App Name: $appName');
              log('Package Name: $packageName');

              SharePlus.instance.share(
                ShareParams(
                  title: appName,
                  subject: 'Check out this awesome Chess App!',
                  text:
                      "I found this amazing Chess App that I think you'll love! \n$appLink",
                ),
              );
            },
          ),
          // _buildListTile(
          //   title: 'Invite a Friend',
          //   icon: Icons.person_add,
          //   onTap: () {
          //     final appLink =
          //         'https://example.com/chess-app'; // Replace with your app link
          //     SharePlus.instance.share(
          //       ShareParams(
          //         title: 'FLC Chess App',
          //         subject: 'Join me on this amazing Chess App!',
          //         text: "Join me on this amazing Chess App! \n$appLink",
          //       ),
          //     );
          //   },
          // ),
          _buildListTile(
            title: 'Community Poll',
            icon: Icons.poll,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CommunityPollScreen(user: widget.user),
                ),
              );
            },
          ),
          const MessagesListTile(),
          if (!widget.user.isGuest)
            _buildListTile(
              title: 'Account status',
              icon: Icons.shield_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AccountStatusScreen()),
                );
              },
            ),
          if (!widget.user.isGuest) const DailyReminderTile(),
          const Divider(),
          _buildSectionHeader('App Actions'),
          // _buildListTile(
          //   title: 'Notifications',
          //   icon: Icons.notifications,
          //   onTap: () async {
          //     // Navigate to system notification settings
          //     // first check platform
          //     if (Theme.of(context).platform == TargetPlatform.android) {
          //       OpenSettingsPlusAndroid settingsPlusAndroid =
          //           OpenSettingsPlusAndroid();
          //       await settingsPlusAndroid.notification();
          //     } else if (Theme.of(context).platform == TargetPlatform.iOS) {
          //       OpenSettingsPlusIOS settingsPlusIOS = OpenSettingsPlusIOS();
          //       ScaffoldMessenger.of(context).showSnackBar(
          //         const SnackBar(
          //           content: Text(
          //             'Please check your device notification settings',
          //           ),
          //           duration: Duration(seconds: 2),
          //         ),
          //       );
          //     } else {
          //       throw Exception('Platform not supported');
          //     }
          //     // ScaffoldMessenger.of(context).showSnackBar(
          //     //   const SnackBar(
          //     //     content: Text(
          //     //       'Please check your device notification settings',
          //     //     ),
          //     //     duration: Duration(seconds: 2),
          //     //   ),
          //     // );
          //   },
          // ),
          _buildListTile(
            title: 'Rate the App',
            icon: Icons.star,
            onTap: () async {
              final InAppReview inAppReview = InAppReview.instance;
              final reviewAvailable = await inAppReview.isAvailable();
              if (!context.mounted) return;
              if (reviewAvailable) {
                log('In-app review is available');
                inAppReview.requestReview();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'In-app review is not available on this device.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const Divider(),
          _buildSectionHeader('About'),
          _buildListTile(
            title: 'About Us',
            icon: Icons.info_outline,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutUsScreen()),
              );
            },
          ),
          _buildListTile(
            title: 'Contact Us',
            icon: Icons.mail_outline,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ContactUsScreen()),
              );
            },
          ),
          _buildListTile(
            title: 'Privacy Settings',
            icon: Icons.security,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Credits & Licenses',
            icon: Icons.favorite,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CreditsScreen()),
              );
            },
          ),
          _buildListTile(
            title: 'Privacy Policy',
            icon: Icons.privacy_tip,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          // const Divider(),
          // _buildSectionHeader('More'),
          // _buildListTile(
          //   title: 'Get More Apps',
          //   icon: Icons.shop,
          //   onTap: () {
          //     launchUrl(
          //       Uri.parse(
          //         'https://play.google.com/store/apps/developer?id=FLC+Business+Group',
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
    ),
    );
  }

  Future<String?> _askApply(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply changes?'),
        content: const Text('You changed the board theme, piece set or piece colours. Apply them before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop('keep'), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.of(ctx).pop('discard'), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop('apply'), child: const Text('Apply')),
        ],
      ),
    );
  }

  // Helper methods to build UI components
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSubHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );

  /// A choice stays usable if it is what the player already has saved (so nobody loses
  /// their current look), otherwise it needs [needed] level.
  bool _isLocked(int needed, bool isSaved) => !isSaved && _level < needed;

  void _showLockedHint(int needed) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Reach level $needed to unlock this. You are level $_level. Complete daily missions to earn XP.'),
        duration: const Duration(seconds: 3),
      ));
  }

  Widget _pickerCard(BuildContext context,
      {required bool selected,
      required VoidCallback onTap,
      required Widget preview,
      required String label,
      int lockLevel = 0}) {
    final scheme = Theme.of(context).colorScheme;
    final locked = lockLevel > 0;
    return GestureDetector(
      onTap: locked ? () => _showLockedHint(lockLevel) : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.topRight, children: [
              Center(child: Opacity(opacity: locked ? 0.35 : 1, child: preview)),
              if (selected) Icon(Icons.check_circle, size: 18, color: scheme.primary),
              if (locked)
                Positioned.fill(
                  child: Center(child: Icon(Icons.lock, size: 22, color: scheme.onSurfaceVariant)),
                ),
            ]),
            const SizedBox(height: 6),
            Text(locked ? 'Level $lockLevel' : label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _miniBoard(BoardStyle st) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 56,
          height: 56,
          child: GridView.count(
            crossAxisCount: 4,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(16, (i) {
              final isLight = ((i ~/ 4) + (i % 4)) % 2 == 0;
              return ColoredBox(color: isLight ? st.light : st.dark);
            }),
          ),
        ),
      );

  Widget _buildBoardThemePicker(BuildContext context, SettingsProvider provider) {
    final current = boardStyleById(_boardId);
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final st in boardStyles)
            _pickerCard(context,
                selected: st.id == current.id,
                onTap: () => setState(() => _boardId = st.id),
                preview: _miniBoard(st),
                label: st.label,
                lockLevel: _isLocked(boardLevelNeeded(st.id), st.id == _savedBoardId) ? boardLevelNeeded(st.id) : 0),
        ],
      ),
    );
  }

  Widget _buildPieceSetPicker(BuildContext context, SettingsProvider provider) {
    Widget textPreview(String t) => SizedBox(
          width: 64,
          height: 36,
          child: Center(child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        );
    return SizedBox(
      height: 98,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _pickerCard(context,
              selected: _pieceId == 'merida',
              onTap: () => setState(() => _pieceId = 'merida'),
              preview: SizedBox(width: 64, height: 36, child: Row(children: [
                Expanded(child: PieceSet.merida().piece(context, 'N')),
                Expanded(child: PieceSet.merida().piece(context, 'n')),
              ])),
              label: 'Merida',
              lockLevel: _isLocked(pieceLevelNeeded('merida'), _savedPieceId == 'merida') ? pieceLevelNeeded('merida') : 0),
          _pickerCard(context,
              selected: _pieceId == 'letters',
              onTap: () => setState(() => _pieceId = 'letters'),
              preview: textPreview('N n'),
              label: 'Letters',
              lockLevel: _isLocked(pieceLevelNeeded('letters'), _savedPieceId == 'letters') ? pieceLevelNeeded('letters') : 0),
          for (final im in imagePieceStyles)
            _pickerCard(context,
                selected: _pieceId == im.id,
                onTap: () => setState(() => _pieceId = im.id),
                preview: SizedBox(width: 64, height: 36, child: Row(children: [
                  Expanded(child: imagePiece(im.id, 'N')),
                  Expanded(child: imagePiece(im.id, 'n')),
                ])),
                label: im.label,
                lockLevel: _isLocked(pieceLevelNeeded(im.id), _savedPieceId == im.id) ? pieceLevelNeeded(im.id) : 0),
          for (final ps in glyphPieceStyles)
            _pickerCard(context,
                selected: _pieceId == ps.id,
                onTap: () => setState(() => _pieceId = ps.id),
                preview: glyphPreview(ps),
                label: ps.label,
                lockLevel: _isLocked(pieceLevelNeeded(ps.id), _savedPieceId == ps.id) ? pieceLevelNeeded(ps.id) : 0),
        ],
      ),
    );
  }

  Widget _swatchRow(BuildContext context,
      {required String title,
      required List<Color> palette,
      required Color? current,
      required ValueChanged<Color?> onPick}) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(Color? c, {bool isDefault = false}) {
      final selected = current?.toARGB32() == c?.toARGB32();
      return GestureDetector(
        onTap: () => onPick(c),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c ?? scheme.surfaceContainerHighest,
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
          ),
          child: isDefault
              ? Icon(Icons.block, size: 18, color: scheme.onSurfaceVariant)
              : (selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            dot(null, isDefault: true),
            for (final c in palette) dot(c),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPieceColors(BuildContext context, SettingsProvider provider) {
    final isGlyph = glyphPieceSetById(_pieceId) != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isGlyph)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text('This piece set has its own colours. Pick Merida, Chessnut, Fantasy, Spatial or Celtic to change colours.',
              style: TextStyle(fontSize: 12)),
        ),
      _swatchRow(context,
          title: 'White pieces',
          palette: whitePiecePalette,
          current: _white,
          onPick: (c) => setState(() => _white = c)),
      _swatchRow(context,
          title: 'Black pieces',
          palette: blackPiecePalette,
          current: _black,
          onPick: (c) => setState(() => _black = c)),
    ]);
  }

  /// Bigger preview of the draft choices (board + pieces + colours).
  Widget _buildLivePreview(BuildContext context, SettingsProvider provider) {
    final style = boardStyleById(_boardId);
    final set = provider.pieceSetFor(_pieceId, _white, _black);
    final lightColor = provider.colorBlindMode ? colorBlindBoardTheme.lightSquare : style.light;
    final darkColor = provider.colorBlindMode ? colorBlindBoardTheme.darkSquare : style.dark;
    const rows = ['rnbqkbnr', 'pppppppp', '        ', 'PPPPPPPP', 'RNBQKBNR'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (context, c) {
          final cell = c.maxWidth / 8;
          return Column(children: [
            for (var r = 0; r < rows.length; r++)
              Row(children: [
                for (var f = 0; f < 8; f++)
                  Container(
                    width: cell,
                    height: cell,
                    color: (r + f) % 2 == 0 ? lightColor : darkColor,
                    padding: EdgeInsets.all(cell * 0.04),
                    child: rows[r][f] == ' ' ? null : set.piece(context, rows[r][f]),
                  ),
              ]),
          ]);
        }),
      ),
    );
  }

  Widget _buildApplyBar(BuildContext context, SettingsProvider provider) {
    final dirty = _isDirty(provider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: dirty ? () => setState(() => _loadFrom(provider)) : null,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.check),
            onPressed: dirty
                ? () {
                    provider.applyAppearance(
                      boardTheme: boardStyleById(_boardId).theme,
                      pieceSet: _pieceId,
                      white: _white,
                      black: _black,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Applied'), duration: Duration(seconds: 1)),
                    );
                  }
                : null,
            label: const Text('Apply'),
          ),
        ),
      ]),
    );
  }

  Widget _buildToggleSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildListTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}
