import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

class UnreadBadgeWidget extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;
  final Color? textColor;
  final double? badgeSize;
  final Function()? onTap;

  const UnreadBadgeWidget({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor,
    this.textColor,
    this.badgeSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return badges.Badge(
      //position: badges.BadgePosition.topEnd(top: -10, end: -12),
      showBadge: count > 0,
      ignorePointer: false,
      onTap: onTap,
      badgeContent: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      badgeAnimation: const badges.BadgeAnimation.scale(
        animationDuration: Duration(seconds: 1),
        colorChangeAnimationDuration: Duration(seconds: 1),
        loopAnimation: false,
        curve: Curves.fastOutSlowIn,
        colorChangeAnimationCurve: Curves.easeInCubic,
      ),
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.circle,
        badgeColor: badgeColor ?? Colors.red,
        padding: const EdgeInsets.all(5),
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white, width: 1),
        elevation: 2,
      ),
      child: child,
    );
  }
}
