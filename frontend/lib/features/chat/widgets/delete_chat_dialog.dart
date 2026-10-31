import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_controller.dart';

class DeleteChatResult {
  final bool deleteForEveryone;
  const DeleteChatResult({required this.deleteForEveryone});
}

/// Telegram-style sleek Delete Chat dialog matching our app's theme:
/// - "ChatGo" header styled with theme.textPrimary
/// - "Are you sure you want to delete the chat?" with theme.textSecondary
/// - Interactive circle toggle "Delete for Me and [Partner Name]" using theme.primaryColor
/// - Dual stadium buttons: Cancel (theme-adaptive) & Delete (theme.primaryGradient)
class DeleteChatDialog extends StatefulWidget {
  final String partnerName;

  const DeleteChatDialog({
    super.key,
    required this.partnerName,
  });

  static Future<DeleteChatResult?> show(
    BuildContext context, {
    required String partnerName,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog<DeleteChatResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => DeleteChatDialog(partnerName: partnerName),
    );
  }

  @override
  State<DeleteChatDialog> createState() => _DeleteChatDialogState();
}

class _DeleteChatDialogState extends State<DeleteChatDialog> {
  bool _deleteForEveryone = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        final isDark = theme.isDark;
        final primaryColor = theme.primaryColor;
        final secondaryColor = theme.secondaryColor;

        final dialogBg = theme.cardBg;
        final borderColor = isDark
            ? Colors.white.withOpacity(0.12)
            : theme.border;

        final cancelButtonBg = isDark
            ? Colors.white.withOpacity(0.10)
            : theme.inputFill;
        final cancelBorderColor = isDark
            ? Colors.white.withOpacity(0.06)
            : theme.border.withOpacity(0.6);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Title "ChatGo"
                Center(
                  child: Text(
                    'ChatGo',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Subtitle prompt
                Text(
                  'Are you sure you want to delete the chat?',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: theme.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Telegram-style Circle Checkbox Option: "Delete for Me and <Partner>"
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _deleteForEveryone = !_deleteForEveryone;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _deleteForEveryone ? primaryColor : Colors.transparent,
                              border: Border.all(
                                color: _deleteForEveryone
                                    ? primaryColor
                                    : (isDark ? Colors.white38 : theme.textMuted.withOpacity(0.6)),
                                width: 1.8,
                              ),
                            ),
                            child: _deleteForEveryone
                                ? const Center(
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Delete for Me and ${widget.partnerName}',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w400,
                                color: theme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Bottom Action Buttons: Cancel (theme-adaptive) & Delete (theme-accented)
                Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cancelButtonBg,
                            foregroundColor: theme.textPrimary,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            side: BorderSide(
                              color: cancelBorderColor,
                              width: 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Delete
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primaryColor, secondaryColor],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).pop(
                                DeleteChatResult(deleteForEveryone: _deleteForEveryone),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Delete',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
