import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../expression_models.dart';
import '../expression_registry.dart';

/// Renders an Animated Emoji with interactive replay on tap.
///
/// On Mobile (iOS/Android), it plays vector Lottie JSON animations directly.
/// On Web (kIsWeb), it seamlessly plays the 60fps Animated WebP version to bypass
/// CanvasKit's recursive trim-path bug while ensuring identical high-res animation.
class AnimatedEmojiWidget extends StatefulWidget {
  final AnimatedEmojiItem emoji;
  final double size;
  final bool repeat;
  final VoidCallback? onTap;

  const AnimatedEmojiWidget({
    super.key,
    required this.emoji,
    this.size = 32.0,
    this.repeat = true,
    this.onTap,
  });

  @override
  State<AnimatedEmojiWidget> createState() => _AnimatedEmojiWidgetState();
}

class _AnimatedEmojiWidgetState extends State<AnimatedEmojiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _replay() {
    _animController.reset();
    if (widget.repeat) {
      _animController.repeat();
    } else {
      _animController.forward();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      final fluent = ExpressionRegistry.findFluentEmojiByUnicode(widget.emoji.unicodeFallback);
      return GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: fluent != null
                ? Image.network(
                    fluent.fluentUrl,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                  )
                : Text(
                    widget.emoji.unicodeFallback,
                    style: TextStyle(fontSize: widget.size * 0.75),
                  ),
          ),
        ),
      );
    }

    // Web platform: use animated WebP
    if (kIsWeb && widget.emoji.animatedWebpUrl.isNotEmpty) {
      return GestureDetector(
        onTap: _replay,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Image.network(
            widget.emoji.animatedWebpUrl,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) {
              return Center(
                child: Text(
                  widget.emoji.unicodeFallback,
                  style: TextStyle(fontSize: widget.size * 0.75),
                ),
              );
            },
          ),
        ),
      );
    }

    // Native Mobile (iOS/Android): Lottie vector animation
    return GestureDetector(
      onTap: _replay,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.network(
          widget.emoji.lottieUrl,
          controller: _animController,
          onLoaded: (composition) {
            _animController.duration = composition.duration;
            if (widget.repeat) {
              _animController.repeat();
            } else {
              _animController.forward();
            }
          },
          errorBuilder: (context, error, stackTrace) {
            // Fallback to Animated WebP if Lottie fails
            if (widget.emoji.animatedWebpUrl.isNotEmpty) {
              return Image.network(
                widget.emoji.animatedWebpUrl,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) => _buildFallback(),
              );
            }
            return _buildFallback();
          },
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        widget.emoji.unicodeFallback,
        style: TextStyle(fontSize: widget.size * 0.75),
      ),
    );
  }
}
