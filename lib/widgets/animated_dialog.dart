import 'package:flutter/material.dart';

class AnimatedDialog extends StatefulWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final bool scrollable;
  final double? maxWidth;
  final bool showCloseButton;

  const AnimatedDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.contentPadding,
    this.scrollable = false,
    this.maxWidth,
    this.showCloseButton = true,
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
        child: child,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
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

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),

          const Spacer(),

          if (widget.showCloseButton)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
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
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
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
