# frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
lib/
├── core/                               # Cross-cutting foundational modules
│   ├── api/api_client.dart             # API client & HTTP network layer
│   ├── location/location_service.dart  # Geolocation & place tracking
│   ├── providers/profile_provider.dart # Riverpod profile notifier
│   ├── storage/local_chat_storage.dart # SQLite & cached preferences
│   ├── theme/                          # Theme controllers & Liquid Glass palettes
│   ├── voice/                          # Audio recording & playback engine
│   └── websocket/chat_socket_service.dart # Real-time socket service
├── features/                           # Domain feature modules
│   ├── auth/
│   │   └── screens/auth_screen.dart    # Login & registration flow (369 lines)
│   ├── home/
│   │   └── screens/home_dashboard_screen.dart # Main shell & tab indexed stack (128 lines)
│   ├── chat/
│   │   ├── screens/
│   │   │   ├── chat_screen.dart        # Decomposed orchestrator (834 lines, down from 3,298!)
│   │   │   ├── chat_list_screen.dart   # Conversations list & filters (644 lines, down from 889)
│   │   │   └── chat_search_screen.dart # Search screen (501 lines)
│   │   └── widgets/
│   │       ├── chat_app_bar.dart       # Glassmorphic header with user info & status (190 lines)
│   │       ├── chat_message_list.dart  # Virtualized list with reverse scrolling & pagination (131 lines)
│   │       ├── chat_message_bubble.dart# Bubble layout, media rendering & styles (809 lines)
│   │       ├── chat_input_bar.dart     # Input field, attachments & mic triggers (154 lines)
│   │       ├── chat_voice_recorder_bar.dart # Live waveform & audio preview (305 lines)
│   │       ├── chat_message_action_menu.dart # Emoji reaction bar & action sheet (255 lines)
│   │       ├── chat_forward_sheet.dart # Contact selector forward modal (162 lines)
│   │       └── chat_list_tile.dart     # Modular conversation tile item (275 lines)
│   ├── contacts/
│   │   └── screens/contacts_screen.dart# People list & online filters (487 lines)
│   ├── profile/
│   │   ├── screens/
│   │   │   ├── profile_screen.dart     # Current user profile settings (813 lines)
│   │   │   ├── user_profile_screen.dart# Partner profile screen (970 lines, down from 989)
│   │   │   └── edit_profile_screen.dart# Edit name, username & avatar (527 lines)
│   │   └── widgets/
│   │       ├── user_profile_hero.dart  # Hero avatar, badge & quick action row (256 lines)
│   │       └── user_profile_info_card.dart # Bio, ID & metadata info card (135 lines)
│   ├── settings/
│   │   └── screens/
│   │       ├── theme_settings_screen.dart # Accent & bubble customizer (829 lines)
│   │       └── privacy_settings_screen.dart # Privacy & GPS toggles (444 lines)
│   └── media/
│       ├── screens/media_viewer_screen.dart # Full-screen image & media viewer (632 lines)
│       └── widgets/
│           ├── media_attachment_picker_sheet.dart # Camera/gallery/doc sheet (480 lines)
│           ├── location_view.dart      # Real-time GPS location selector (702 lines)
│           └── cartodb_map_view.dart   # Interactive vector tile canvas (179 lines)
├── shared/ (and lib/widgets/)          # Reusable UI components
│   ├── liquid_background.dart, liquid_button.dart, liquid_glass_card.dart, liquid_text_field.dart
│   ├── clay_menu_bar.dart, app_search_bar.dart, app_toast.dart
└── screens/ & widgets/                 # Backward-compatible barrel re-exports (1-line files)

