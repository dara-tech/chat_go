import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/liquid_glass_theme.dart';

class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onClose;
  final bool showClearButton;
  final EdgeInsetsGeometry margin;
  final double height;

  const AppSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search (⌘K)',
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onClose,
    this.showClearButton = true,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.height = 40,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  TextEditingController? _localController;
  FocusNode? _localFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_localController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_localFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChanged);
    if (!widget.readOnly) {
      _focusNode.addListener(_onStateChanged);
    }
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onStateChanged);
      _controller.addListener(_onStateChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onStateChanged);
      if (!widget.readOnly) {
        _focusNode.addListener(_onStateChanged);
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller != null) {
      widget.controller!.removeListener(_onStateChanged);
    } else {
      _localController?.removeListener(_onStateChanged);
    }
    _localController?.dispose();

    if (widget.focusNode != null) {
      widget.focusNode!.removeListener(_onStateChanged);
    } else {
      _localFocusNode?.removeListener(_onStateChanged);
    }
    _localFocusNode?.dispose();

    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _handleClearOrClose() {
    if (_controller.text.isNotEmpty) {
      _controller.clear();
      widget.onChanged?.call('');
      widget.onClear?.call();
    } else {
      _focusNode.unfocus();
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.readOnly ? false : _controller.text.isNotEmpty;
    final isClicked = widget.readOnly ? false : _focusNode.hasFocus;
    // 'x' is enabled/shown ONLY when input is clicked/focused or has text
    final showX = !widget.readOnly && widget.showClearButton && (isClicked || hasText);

    return Container(
      margin: widget.margin,
      height: widget.height,
      decoration: BoxDecoration(
        color: LiquidGlassTheme.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.readOnly ? widget.onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Search Icon (Always CupertinoIcons.search like screenshot)
                Icon(
                  CupertinoIcons.search,
                  size: 17,
                  color: LiquidGlassTheme.textMuted,
                ),
                const SizedBox(width: 8),

                // Input Text or ReadOnly Display
                Expanded(
                  child: widget.readOnly
                      ? Text(
                          widget.hintText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: LiquidGlassTheme.textMuted,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      : TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: widget.autofocus,
                          textAlignVertical: TextAlignVertical.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: LiquidGlassTheme.textPrimary,
                          ),
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              color: LiquidGlassTheme.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                ),

                // 'x' inside the input box - ONLY shown when input is clicked/focused or has text
                if (showX)
                  GestureDetector(
                    onTap: _handleClearOrClose,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 18,
                        color: LiquidGlassTheme.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
