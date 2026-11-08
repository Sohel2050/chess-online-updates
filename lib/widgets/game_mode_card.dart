import 'package:flutter/material.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/mode_live_stats.dart';

/// Banner artwork of one game mode (the title and time control are part of the picture).
class _ModeArt {
  final String asset;
  final double aspect; // width / height of the picture
  final Color glow;

  /// True when the picture itself has square corners (we round them in code).
  final bool roundInCode;
  const _ModeArt(this.asset, this.aspect, this.glow, {this.roundInCode = false});
}

/// All three banners share one canvas (1100 x 386) with transparent rounded edges.
/// Change ONLY these when you replace the pictures with taller ones
/// (e.g. 1100 x 540 -> width 1100, height 540). The card and the carousel
/// height in play_screen.dart follow automatically.
const double kModeBannerWidthPx = 1100;
const double kModeBannerHeightPx = 540;
const double kModeBannerAspect = kModeBannerWidthPx / kModeBannerHeightPx;
const double _bannerAspect = kModeBannerAspect;

/// The visible frame starts this far from the top of the canvas (24 of 386 px);
/// the top is left free for things that stick out of the frame (like a badge).
const double _frameTopFraction = 24 / 540;

_ModeArt _artFor(String title) {
  switch (title) {
    case Constants.fast:
      return const _ModeArt('assets/images/mode_fast.png', _bannerAspect, Color(0xFF38BDF8));
    case Constants.blitz3:
      return const _ModeArt('assets/images/mode_blitz.png', _bannerAspect, Color(0xFFF97316));
    default: // Classical and anything else
      return const _ModeArt('assets/images/mode_classical.png', _bannerAspect, Color(0xFFFACC15));
  }
}

class GameModeCard extends StatelessWidget {
  final String title;
  final String timeControl;
  final bool isSelected;
  final VoidCallback onTap;

  /// Show this mode's live waiting / running-games counters under the banner.
  final bool showLiveStats;

  /// Floats on the picture's top-right corner (the online game settings button).
  final Widget? trailing;

  const GameModeCard({
    super.key,
    required this.title,
    required this.timeControl,
    this.isSelected = false,
    required this.onTap,
    this.showLiveStats = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final art = _artFor(title);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AspectRatio(
          aspectRatio: art.aspect,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isSelected ? 1 : 0.88,
            child: LayoutBuilder(
              builder: (context, box) {
                final top = box.maxHeight * _frameTopFraction + box.maxHeight * 0.035;
                final side = box.maxWidth * 0.045;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        art.asset,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    // Waiting / games running: floats on the picture's top-left corner.
                    if (showLiveStats)
                      Positioned(
                        top: top,
                        left: side,
                        child: ModeLiveStats(gameMode: timeControl),
                      ),
                    // Game settings: floats on the picture's top-right corner.
                    if (trailing != null)
                      Positioned(top: top, right: side, child: trailing!),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
