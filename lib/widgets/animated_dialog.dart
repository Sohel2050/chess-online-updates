import 'package:flutter/material.dart';
import 'package:flutter_chess_app/utils/adaptive.dart';

class AnimatedDialog extends StatefulWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final bool scrollable;
  final double? maxWidth;
  final bool showCloseButton;

  /// Red warning style for actions that lose something (quit, delete, block...).
  final bool isDestructive;

  /// Icon shown in a round badge before the title.
  final IconData? icon;

  const AnimatedDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.contentPadding,
    this.scrollable = false,
    this.maxWidth,
    this.showCloseButton = true,
    this.isDestructive = false,
    this.icon,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    EdgeInsetsGeometry? contentPadding,
    bool scrollable = false,
    double? maxWidth,
    bool barrierDismissible = false,
    bool showCloseButton = true,
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      pageBuilder: (context, animation, secondaryAnimation) => AnimatedDialog(
        title: title,
        actions: actions,
        contentPadding: contentPadding,
        scrollable: scrollable,
        maxWidth: maxWidth,
        showCloseButton: showCloseButton,
        isDestructive: isDestructive,
        icon: icon,
        child: child,
      ),
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        if (isIOS) {
          // iOS alerts fade and scale in from the centre instead of sliding up.
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.1, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        }
        const begin = Offset(0.0, 0.3);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  State<AnimatedDialog> createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<AnimatedDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final effectiveMaxWidth = widget.maxWidth ?? screenSize.width * 0.8;
    if (isIOS) return _buildIOS(context, screenSize, effectiveMaxWidth);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: widget.isDestructive
            ? BorderSide(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35),
              )
            : BorderSide.none,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: effectiveMaxWidth,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null) _buildHeader(context),
            if (widget.scrollable)
              Flexible(
                child: SingleChildScrollView(
                  padding: widget.contentPadding ?? const EdgeInsets.all(24),
                  child: widget.child,
                ),
              )
            else
              Flexible(
                child: Padding(
                  padding: widget.contentPadding ?? const EdgeInsets.all(24),
                  child: widget.child,
                ),
              ),
            if (widget.actions != null) _buildActions(context),
          ],
        ),
      ),
    );
  }

  /// iOS alert look: centred bold title, plain rounded sheet, no header
  /// gradient / icon badge / close "X". A "Close" button replaces the X when
  /// the dialog has no actions of its own (so it can still be dismissed).
  Widget _buildIOS(BuildContext context, Size screenSize, double maxWidth) {
    final cs = Theme.of(context).colorScheme;
    final danger = widget.isDestructive;
    final actions =
        widget.actions ??
        (widget.showCloseButton
            ? <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ]
            : null);
    final padding = widget.contentPadding ?? const EdgeInsets.all(20);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      backgroundColor: cs.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  widget.title!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: danger ? cs.error : null,
                  ),
                ),
              ),
            Flexible(
              child: widget.scrollable
                  ? SingleChildScrollView(padding: padding, child: widget.child)
                  : Padding(padding: padding, child: widget.child),
            ),
            if (actions != null) ...[
              Divider(height: 1, color: cs.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final danger = widget.isDestructive;
    final Color bg = danger ? cs.errorContainer : cs.secondaryContainer;
    final Color fg = danger ? cs.onErrorContainer : cs.onSecondaryContainer;
    final IconData? icon =
        widget.icon ?? (danger ? Icons.warning_amber_rounded : null);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Color.alphaBlend(cs.surface.withValues(alpha: 0.35), bg)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (danger ? cs.error : cs.primary).withValues(alpha: 0.15),
              ),
              child: Icon(icon, size: 22, color: danger ? cs.error : cs.primary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (widget.showCloseButton)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: fg),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: widget.actions!.map((action) {
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: action,
          );
        }).toList(),
      ),
    );
  }
}

/// Pill-shaped "Cancel / No / Stay" button for dialog action rows.
class DialogCancelButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const DialogCancelButton({super.key, this.text = 'Cancel', this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      ),
      child: Text(text),
    );
  }
}

/// Red filled button for the action that loses something (Quit, Delete, Block...).
class DialogDangerButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;

  const DialogDangerButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onPressed ?? () => Navigator.of(context).pop(true),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(text),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: cs.error.withValues(alpha: 0.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
