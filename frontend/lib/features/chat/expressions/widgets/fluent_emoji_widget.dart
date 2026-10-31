import 'package:flutter/material.dart';

import '../expression_models.dart';

/// Renders a Fluent 3D Emoji with instant fallback to native Unicode
class FluentEmojiWidget extends StatelessWidget {
  final FluentEmojiItem emoji;
  final double size;
  final VoidCallback? onTap;

  const FluentEmojiWidget({
    super.key,
    required this.emoji,
    this.size = 28.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          emoji.fluentUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                emoji.unicode,
                style: TextStyle(
                  fontSize: size * 0.75,
                  height: 1.1,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
