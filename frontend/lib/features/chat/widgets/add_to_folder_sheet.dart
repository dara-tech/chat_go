import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/chat_folder_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/group_model.dart';
import '../../../models/user_model.dart';
import '../../settings/screens/chat_folders_settings_screen.dart';

/// Bottom sheet dialog to add or remove a chat from user folders.
class AddToFolderSheet extends StatelessWidget {
  final UserModel? user;
  final ChatGroup? group;

  const AddToFolderSheet({
    super.key,
    this.user,
    this.group,
  });

  static void show(
    BuildContext context, {
    UserModel? user,
    ChatGroup? group,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddToFolderSheet(user: user, group: group),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = group?.name ?? user?.displayName ?? user?.username ?? 'Chat';

    return ListenableBuilder(
      listenable: ChatFolderController.instance,
      builder: (context, _) {
        final controller = ChatFolderController.instance;
        final folders = controller.customFolders;
        final primaryColor = ThemeController.instance.primaryColor;
        final cardBg = ThemeController.instance.cardBg;
        final dividerColor = ThemeController.instance.divider;
        final textPrimary = ThemeController.instance.textPrimary;
        final textSecondary = ThemeController.instance.textSecondary;
        final textMuted = ThemeController.instance.textMuted;

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to Folder',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.clear_circled_solid),
                      color: textMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: dividerColor),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No custom folders created yet.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: folders.length,
                    separatorBuilder: (_, _) => Divider(height: 1, indent: 56, color: dividerColor),
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      final isSelected = controller.isChatInFolder(
                        folder.id,
                        userId: user?.id,
                        groupId: group?.id,
                      );

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: primaryColor,
                        secondary: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            folder.iconData,
                            size: 16,
                            color: primaryColor,
                          ),
                        ),
                        title: Text(
                          folder.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                        onChanged: (_) {
                          controller.toggleChatInFolder(
                            folder.id,
                            userId: user?.id,
                            groupId: group?.id,
                          );
                        },
                      );
                    },
                  ),
                ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: Icon(CupertinoIcons.folder_badge_plus, color: primaryColor),
                title: Text(
                  'Manage Folders',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                trailing: Icon(CupertinoIcons.chevron_right, size: 14, color: textMuted),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatFoldersSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
