import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

import '../expression_models.dart';

/// Renders an Interactive Reaction using Rive with responsive tap & state machine feedback
class InteractiveReactionWidget extends StatefulWidget {
  final InteractiveReactionItem reaction;
  final double size;
  final VoidCallback? onTap;

  const InteractiveReactionWidget({
    super.key,
    required this.reaction,
    this.size = 36.0,
    this.onTap,
  });

  @override
  State<InteractiveReactionWidget> createState() => _InteractiveReactionWidgetState();
}

class _InteractiveReactionWidgetState extends State<InteractiveReactionWidget> {
  RiveWidgetController? _controller;
  bool _hasError = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    _controller?.active = true;
    _controller?.scheduleRepaint();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: Text(
              widget.reaction.unicodeFallback,
              style: TextStyle(fontSize: widget.size * 0.70),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RiveWidgetBuilder(
          fileLoader: FileLoader.fromUrl(
            widget.reaction.riveUrl,
            riveFactory: Factory.rive,
          ),
          artboardSelector: widget.reaction.artboard != null
              ? ArtboardNamed(widget.reaction.artboard!)
              : const ArtboardDefault(),
          stateMachineSelector: widget.reaction.stateMachineName != null
              ? StateMachineNamed(widget.reaction.stateMachineName!)
              : const StateMachineDefault(),
          onLoaded: (state) {
            _controller = state.controller;
          },
          onFailed: (error, stackTrace) {
            if (mounted) setState(() => _hasError = true);
          },
          builder: (context, state) {
            if (state is RiveLoaded) {
              return RiveWidget(
                controller: state.controller,
                fit: Fit.contain,
              );
            }
            if (state is RiveFailed) {
              return Center(
                child: Text(
                  widget.reaction.unicodeFallback,
                  style: TextStyle(fontSize: widget.size * 0.70),
                ),
              );
            }
            return Center(
              child: Text(
                widget.reaction.unicodeFallback,
                style: TextStyle(fontSize: widget.size * 0.65),
              ),
            );
          },
        ),
      ),
    );
  }
}
