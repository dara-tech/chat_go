import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../expression_models.dart';

/// Renders an Animated Sticker (WebP) with transparent background and smooth caching
class AnimatedStickerWidget extends StatelessWidget {
  final AnimatedStickerItem sticker;
  final double size;
  final VoidCallback? onTap;

  const AnimatedStickerWidget({
    super.key,
    required this.sticker,
    this.size = 120.0,
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
          sticker.webpUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.35,
                height: size * 0.35,
                child: const CupertinoActivityIndicator(radius: 10),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                CupertinoIcons.photo,
                size: size * 0.4,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }
}
