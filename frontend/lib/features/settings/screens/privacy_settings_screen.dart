import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/location/location_service.dart';
import 'package:frontend/core/notifications/notification_alert_service.dart';
import 'package:frontend/core/services/media_download_service.dart';
import 'package:frontend/core/theme/liquid_glass_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  int _mediaCacheSizeBytes = 0;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    LocationService.instance.init();
    NotificationAlertService.instance.loadPreferences();
    MediaDownloadService.instance.loadPreferences();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final size = await MediaDownloadService.instance.getCachedMediaSizeBytes();
    if (mounted) {
      setState(() {
        _mediaCacheSizeBytes = size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          backgroundColor: ThemeController.instance.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      bottomInset > 0 ? bottomInset + 32 : 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('NOTIFICATIONS & ALERT PRIVACY'),
                        _buildNotificationAlertCard(context),
                        const SizedBox(height: 24),
                        _buildSectionHeader('MEDIA & STORAGE PRIVACY'),
                        _buildMediaPrivacyCard(context),
                        const SizedBox(height: 24),
                        _buildSectionHeader('LOCATION & GPS PRIVACY'),
                        _buildGpsPrivacyCard(context),
                        const SizedBox(height: 24),
                        _buildSectionHeader('ENCRYPTION & SECURITY'),
                        _buildSecurityCard(context),
                        const SizedBox(height: 24),
                        _buildSectionHeader('DATA & PRIVACY POLICY'),
                        _buildDataPolicyCard(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bgPreset = ThemeController.instance.bgPreset;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgPreset.surfaceBg,
        border: Border(
          bottom: BorderSide(
            color: LiquidGlassTheme.dividerHairline,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgPreset.inputFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: LiquidGlassTheme.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.chevron_back,
                color: bgPreset.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Security & Privacy',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: bgPreset.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: ThemeController.instance.bgPreset.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNotificationAlertCard(BuildContext context) {
    final bgPreset = ThemeController.instance.bgPreset;
    final primaryColor = ThemeController.instance.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: bgPreset.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: NotificationAlertService.instance.bannerEnabledNotifier,
        builder: (context, bannerEnabled, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: NotificationAlertService.instance.soundEnabledNotifier,
            builder: (context, soundEnabled, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: NotificationAlertService.instance.hapticEnabledNotifier,
                builder: (context, hapticEnabled, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: NotificationAlertService.instance.previewEnabledNotifier,
                    builder: (context, previewEnabled, _) {
                      return Column(
                        children: [
                          _buildSwitchTile(
                            icon: CupertinoIcons.bell_fill,
                            iconColor: primaryColor,
                            title: 'In-App Banner Alerts',
                            subtitle: 'Display floating banner at the top of the screen when new messages arrive.',
                            value: bannerEnabled,
                            onChanged: (val) {
                              NotificationAlertService.instance.setBannerEnabled(val);
                            },
                          ),
                          Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
                          _buildSwitchTile(
                            icon: CupertinoIcons.speaker_2_fill,
                            iconColor: const Color(0xFF0EA5E9),
                            title: 'Sound & Chimes',
                            subtitle: 'Play audio alert chime on incoming messages.',
                            value: soundEnabled,
                            onChanged: (val) {
                              NotificationAlertService.instance.setSoundEnabled(val);
                            },
                          ),
                          Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
                          _buildSwitchTile(
                            icon: CupertinoIcons.waveform_path,
                            iconColor: const Color(0xFF8B5CF6),
                            title: 'Haptic Feedback',
                            subtitle: 'Vibrate device on incoming messages.',
                            value: hapticEnabled,
                            onChanged: (val) {
                              NotificationAlertService.instance.setHapticEnabled(val);
                            },
                          ),
                          Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
                          _buildSwitchTile(
                            icon: CupertinoIcons.eye_fill,
                            iconColor: const Color(0xFFF59E0B),
                            title: 'Show Message Preview',
                            subtitle: 'Display sender name and message content. Turn off to hide details on alerts.',
                            value: previewEnabled,
                            onChanged: (val) {
                              NotificationAlertService.instance.setPreviewEnabled(val);
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMediaPrivacyCard(BuildContext context) {
    final bgPreset = ThemeController.instance.bgPreset;
    final primaryColor = ThemeController.instance.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: bgPreset.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: MediaDownloadService.instance.autoDownloadWifiNotifier,
        builder: (context, autoWifi, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: MediaDownloadService.instance.autoDownloadCellularNotifier,
            builder: (context, autoCellular, _) {
              return Column(
                children: [
                  _buildSwitchTile(
                    icon: CupertinoIcons.wifi,
                    iconColor: primaryColor,
                    title: 'Auto-Download Over Wi-Fi',
                    subtitle: 'Automatically cache photos and media files when connected to Wi-Fi.',
                    value: autoWifi,
                    onChanged: (val) {
                      MediaDownloadService.instance.setAutoDownloadWifi(val);
                    },
                  ),
                  Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
                  _buildSwitchTile(
                    icon: CupertinoIcons.antenna_radiowaves_left_right,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Auto-Download Over Cellular',
                    subtitle: 'Automatically download media files using cellular mobile data.',
                    value: autoCellular,
                    onChanged: (val) {
                      MediaDownloadService.instance.setAutoDownloadCellular(val);
                    },
                  ),
                  Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
                  _buildClearCacheTile(context),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildClearCacheTile(BuildContext context) {
    final bgPreset = ThemeController.instance.bgPreset;
    final formattedSize = MediaDownloadService.instance.formatBytes(_mediaCacheSizeBytes);

    return InkWell(
      onTap: _isClearingCache ? null : () => _confirmClearCache(context),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.trash_fill,
                color: Color(0xFFEF4444),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clear Media Cache',
                    style: GoogleFonts.outfit(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: bgPreset.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Free up storage by clearing cached photos, audios and files from device memory.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: bgPreset.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bgPreset.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
              ),
              child: _isClearingCache
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      formattedSize,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _mediaCacheSizeBytes > 0 ? const Color(0xFFEF4444) : bgPreset.textMuted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          'Clear Media Cache',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        message: Text(
          'This will remove all downloaded files (${MediaDownloadService.instance.formatBytes(_mediaCacheSizeBytes)}) from your device storage. You can re-download them anytime.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _isClearingCache = true);
              await MediaDownloadService.instance.clearMediaCache();
              await _refreshCacheSize();
              if (mounted) {
                setState(() => _isClearingCache = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Media cache cleared successfully',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                    ),
                    backgroundColor: LiquidGlassTheme.bgCard,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Clear Cache'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildGpsPrivacyCard(BuildContext context) {
    final bgPreset = ThemeController.instance.bgPreset;
    final primaryColor = ThemeController.instance.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: bgPreset.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: LocationService.instance.allowGpsNotifier,
        builder: (context, allowGps, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: LocationService.instance.preciseLocationNotifier,
            builder: (context, preciseLocation, _) {
              return Column(
                children: [
                  _buildSwitchTile(
                    icon: CupertinoIcons.location_fill,
                    iconColor: primaryColor,
                    title: 'Allow GPS Location',
                    subtitle: 'Detect your real-time coordinates when using the location picker.',
                    value: allowGps,
                    onChanged: (val) {
                      LocationService.instance.setAllowGps(val);
                    },
                  ),
                  Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
                  _buildSwitchTile(
                    icon: CupertinoIcons.scope,
                    iconColor: allowGps ? primaryColor : bgPreset.textMuted,
                    title: 'Precise GPS Location',
                    subtitle: 'Uses meter-accurate satellite GPS positioning instead of approximate city-level location.',
                    value: allowGps && preciseLocation,
                    onChanged: allowGps
                        ? (val) {
                            LocationService.instance.setPreciseLocation(val);
                          }
                        : null,
                  ),
                  Divider(height: 1, thickness: 0.8, color: LiquidGlassTheme.dividerHairline),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: allowGps
                          ? primaryColor.withOpacity(0.04)
                          : bgPreset.inputFill.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          allowGps ? CupertinoIcons.checkmark_shield_fill : CupertinoIcons.xmark_shield_fill,
                          size: 15,
                          color: allowGps ? LiquidGlassTheme.accentEmerald : bgPreset.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            allowGps
                                ? (preciseLocation
                                    ? 'GPS Privacy: Active with high precision'
                                    : 'GPS Privacy: Active with approximate precision')
                                : 'GPS Privacy: Disabled (Default coordinates used)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: allowGps ? bgPreset.textPrimary : bgPreset.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context) {
    final bgPreset = ThemeController.instance.bgPreset;
    final primaryColor = ThemeController.instance.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: bgPreset.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: CupertinoIcons.lock_shield_fill,
            iconColor: const Color(0xFF0D9488),
            title: 'Password Encryption',
            subtitle: 'Protected with multi-round Argon2id and Bcrypt algorithm.',
          ),
          Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
          _buildInfoRow(
            icon: CupertinoIcons.cloud_fill,
            iconColor: primaryColor,
            title: 'Media Storage Security',
            subtitle: 'Photos, videos, and files stored on private Cloudflare R2 buckets.',
          ),
          Divider(height: 1, thickness: 0.8, indent: 64, color: LiquidGlassTheme.dividerHairline),
          _buildInfoRow(
            icon: CupertinoIcons.device_phone_portrait,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Local Database Cache',
            subtitle: 'Message history encrypted and stored locally on your device for instant launch.',
          ),
        ],
      ),
    );
  }

  Widget _buildDataPolicyCard(BuildContext context) {
    final bgPreset = ThemeController.instance.bgPreset;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgPreset.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.hand_raised_fill, size: 16, color: bgPreset.textMuted),
              const SizedBox(width: 8),
              Text(
                'Zero Tracking Guarantee',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: bgPreset.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ChatGo does not sell or share your location data or message history with third parties. Your coordinates and messages are transmitted securely only when you interact in a chat.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: bgPreset.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final bgPreset = ThemeController.instance.bgPreset;
    final primaryColor = ThemeController.instance.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: bgPreset.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: bgPreset.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value,
            activeColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final bgPreset = ThemeController.instance.bgPreset;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: bgPreset.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: bgPreset.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
