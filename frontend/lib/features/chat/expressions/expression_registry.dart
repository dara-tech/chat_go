import 'expression_models.dart';

/// Central repository of curated expressions across all 4 formats:
/// 1. Animated Emoji (Lottie JSON)
/// 2. Animated Stickers (WebP)
/// 3. Interactive Reactions (Rive)
/// 4. Normal Emoji (Unicode / Fluent 3D Emoji)
class ExpressionRegistry {
  ExpressionRegistry._();

  // ==========================================
  // 1. ANIMATED EMOJIS (Lottie JSON + Animated WebP)
  // ==========================================
  static const List<AnimatedEmojiItem> animatedEmojis = [
    AnimatedEmojiItem(
      id: 'party_popper',
      name: 'Party Popper',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f389/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f389/512.webp',
      unicodeFallback: '🎉',
    ),
    AnimatedEmojiItem(
      id: 'red_heart',
      name: 'Beating Heart',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/2764_fe0f/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/2764_fe0f/512.webp',
      unicodeFallback: '❤️',
    ),
    AnimatedEmojiItem(
      id: 'fire',
      name: 'Fire Flame',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f525/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f525/512.webp',
      unicodeFallback: '🔥',
    ),
    AnimatedEmojiItem(
      id: 'laughing',
      name: 'Laughing Joy',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/512.webp',
      unicodeFallback: '😂',
    ),
    AnimatedEmojiItem(
      id: 'thumbs_up',
      name: 'Thumbs Up',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44d/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44d/512.webp',
      unicodeFallback: '👍',
    ),
    AnimatedEmojiItem(
      id: 'crying',
      name: 'Loudly Crying',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/512.webp',
      unicodeFallback: '😭',
    ),
    AnimatedEmojiItem(
      id: 'thinking',
      name: 'Thinking Face',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f914/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f914/512.webp',
      unicodeFallback: '🤔',
    ),
    AnimatedEmojiItem(
      id: 'mind_blown',
      name: 'Exploding Head',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92f/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92f/512.webp',
      unicodeFallback: '🤯',
    ),
    AnimatedEmojiItem(
      id: 'star_struck',
      name: 'Star Struck',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f929/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f929/512.webp',
      unicodeFallback: '🤩',
    ),
    AnimatedEmojiItem(
      id: 'rocket',
      name: 'Rocket Launch',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.webp',
      unicodeFallback: '🚀',
    ),
    AnimatedEmojiItem(
      id: 'clapping',
      name: 'Clapping Hands',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44f/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44f/512.webp',
      unicodeFallback: '👏',
    ),
    AnimatedEmojiItem(
      id: 'hundred',
      name: '100 Points',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f4af/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f4af/512.webp',
      unicodeFallback: '💯',
    ),
    AnimatedEmojiItem(
      id: 'heart_eyes',
      name: 'Heart Eyes',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60d/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60d/512.webp',
      unicodeFallback: '😍',
    ),
    AnimatedEmojiItem(
      id: 'partying_face',
      name: 'Partying Face',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/512.webp',
      unicodeFallback: '🥳',
    ),
    AnimatedEmojiItem(
      id: 'grinning',
      name: 'Grinning Face',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f600/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f600/512.webp',
      unicodeFallback: '😀',
    ),
    AnimatedEmojiItem(
      id: 'sunglasses',
      name: 'Cool Sunglasses',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/512.webp',
      unicodeFallback: '😎',
    ),
    AnimatedEmojiItem(
      id: 'sparkling_heart',
      name: 'Sparkling Heart',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f496/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f496/512.webp',
      unicodeFallback: '💖',
    ),
    AnimatedEmojiItem(
      id: 'sparkles',
      name: 'Sparkles',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/2728/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/2728/512.webp',
      unicodeFallback: '✨',
    ),
    AnimatedEmojiItem(
      id: 'pleading_face',
      name: 'Pleading Face',
      lottieUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f97a/lottie.json',
      animatedWebpUrl: 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f97a/512.webp',
      unicodeFallback: '🥺',
    ),
  ];

  // ==========================================
  // 2. ANIMATED STICKERS (WebP)
  // ==========================================
  static const List<AnimatedStickerItem> animatedStickers = [
    // Cat Pack
    AnimatedStickerItem(
      id: 'cat_wave',
      name: 'Cat Wave',
      packId: 'cute_cats',
      packName: 'Cute Cats',
      webpUrl: 'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.webp',
      isAnimated: true,
    ),
    AnimatedStickerItem(
      id: 'cat_popcorn',
      name: 'Eating Popcorn',
      packId: 'cute_cats',
      packName: 'Cute Cats',
      webpUrl: 'https://media.giphy.com/media/o0vwzuFwCGAFO/giphy.webp',
      isAnimated: true,
    ),
    AnimatedStickerItem(
      id: 'cat_dance',
      name: 'Happy Dance',
      packId: 'cute_cats',
      packName: 'Cute Cats',
      webpUrl: 'https://media.giphy.com/media/VbnUQIRNNGLSp9R3NT/giphy.webp',
      isAnimated: true,
    ),
    AnimatedStickerItem(
      id: 'cat_love',
      name: 'Cat In Love',
      packId: 'cute_cats',
      packName: 'Cute Cats',
      webpUrl: 'https://media.giphy.com/media/MDJ9IbxxvDUQM/giphy.webp',
      isAnimated: true,
    ),

    // Duck & Moods Pack
    AnimatedStickerItem(
      id: 'duck_walk',
      name: 'Duck Strut',
      packId: 'duck_moods',
      packName: 'Duck Moods',
      webpUrl: 'https://media.giphy.com/media/krewXUB6LBja/giphy.webp',
      isAnimated: true,
    ),
    AnimatedStickerItem(
      id: 'duck_nod',
      name: 'Duck Nodding',
      packId: 'duck_moods',
      packName: 'Duck Moods',
      webpUrl: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExdWZ3NDg0dDVwZzYwMzkwbzFjcmJldTV4bWFqNWJ4Yzg3OXp0ZXpxeCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/u0b171Pj75j5s1s8jC/giphy.webp',
      isAnimated: true,
    ),
    AnimatedStickerItem(
      id: 'duck_celebrate',
      name: 'Duck Party',
      packId: 'duck_moods',
      packName: 'Duck Moods',
      webpUrl: 'https://media.giphy.com/media/Ju7l5y9osyymQ/giphy.webp',
      isAnimated: true,
    ),

    // Shiba Inu Pack
    AnimatedStickerItem(
      id: 'shiba_cheer',
      name: 'Shiba Cheer',
      packId: 'shiba_vibes',
      packName: 'Shiba Vibes',
      webpUrl: 'https://media.giphy.com/media/chHp2P2Z89eHjJg13e/giphy.webp',
      isAnimated: true,
    ),
    AnimatedStickerItem(
      id: 'shiba_wink',
      name: 'Shiba Wink',
      packId: 'shiba_vibes',
      packName: 'Shiba Vibes',
      webpUrl: 'https://media.giphy.com/media/13CoXDiaCcCoyk/giphy.webp',
      isAnimated: true,
    ),
  ];

  // ==========================================
  // 3. INTERACTIVE REACTIONS (Rive)
  // ==========================================
  static const List<InteractiveReactionItem> interactiveReactions = [
    InteractiveReactionItem(
      id: 'rive_heart',
      name: 'Pulsing Heart',
      riveUrl: 'https://cdn.rive.app/animations/vehicles.riv',
      stateMachineName: 'State Machine 1',
      triggerName: 'Trigger',
      unicodeFallback: '❤️',
    ),
    InteractiveReactionItem(
      id: 'rive_thumb',
      name: 'Like Burst',
      riveUrl: 'https://public.rive.app/community/runtime-files/2191-4327-rating-animation.riv',
      stateMachineName: 'State Machine 1',
      triggerName: 'Bump',
      unicodeFallback: '👍',
    ),
    InteractiveReactionItem(
      id: 'rive_fire',
      name: 'Fire Sparks',
      riveUrl: 'https://cdn.rive.app/animations/off_road_car.riv',
      stateMachineName: 'State Machine 1',
      triggerName: 'Explode',
      unicodeFallback: '🔥',
    ),
    InteractiveReactionItem(
      id: 'rive_party',
      name: 'Confetti Boom',
      riveUrl: 'https://public.rive.app/community/runtime-files/2244-4447-confetti.riv',
      stateMachineName: 'State Machine 1',
      triggerName: 'Boom',
      unicodeFallback: '🎉',
    ),
  ];

  // ==========================================
  // 4. NORMAL EMOJI (Unicode / Fluent 3D Emoji)
  // ==========================================
  static const List<FluentEmojiItem> fluentEmojis = [
    // Smileys & Emotion
    FluentEmojiItem(
      unicode: '😀',
      name: 'Grinning Face',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Grinning%20face/3D/grinning_face_3d.png',
    ),
    FluentEmojiItem(
      unicode: '😂',
      name: 'Face with Tears of Joy',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Face%20with%20tears%20of%20joy/3D/face_with_tears_of_joy_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🥰',
      name: 'Smiling Face with Hearts',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Smiling%20face%20with%20hearts/3D/smiling_face_with_hearts_3d.png',
    ),
    FluentEmojiItem(
      unicode: '😍',
      name: 'Heart Eyes',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Smiling%20face%20with%20heart-eyes/3D/smiling_face_with_heart-eyes_3d.png',
    ),
    FluentEmojiItem(
      unicode: '😎',
      name: 'Smiling Face with Sunglasses',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Smiling%20face%20with%20sunglasses/3D/smiling_face_with_sunglasses_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🤔',
      name: 'Thinking Face',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Thinking%20face/3D/thinking_face_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🤯',
      name: 'Exploding Head',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Exploding%20head/3D/exploding_head_3d.png',
    ),
    FluentEmojiItem(
      unicode: '😭',
      name: 'Loudly Crying Face',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Loudly%20crying%20face/3D/loudly_crying_face_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🥳',
      name: 'Partying Face',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Partying%20face/3D/partying_face_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🥺',
      name: 'Pleading Face',
      category: 'Smileys',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Pleading%20face/3D/pleading_face_3d.png',
    ),

    // Gestures & People
    FluentEmojiItem(
      unicode: '👍',
      name: 'Thumbs Up',
      category: 'Gestures',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Thumbs%20up/Default/3D/thumbs_up_3d_default.png',
    ),
    FluentEmojiItem(
      unicode: '👎',
      name: 'Thumbs Down',
      category: 'Gestures',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Thumbs%20down/Default/3D/thumbs_down_3d_default.png',
    ),
    FluentEmojiItem(
      unicode: '👏',
      name: 'Clapping Hands',
      category: 'Gestures',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Clapping%20hands/Default/3D/clapping_hands_3d_default.png',
    ),
    FluentEmojiItem(
      unicode: '🙌',
      name: 'Raising Hands',
      category: 'Gestures',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Raising%20hands/Default/3D/raising_hands_3d_default.png',
    ),
    FluentEmojiItem(
      unicode: '🤝',
      name: 'Handshake',
      category: 'Gestures',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Handshake/Default/3D/handshake_3d_default.png',
    ),
    FluentEmojiItem(
      unicode: '✌️',
      name: 'Victory Hand',
      category: 'Gestures',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Victory%20hand/Default/3D/victory_hand_3d_default.png',
    ),

    // Hearts & Symbols
    FluentEmojiItem(
      unicode: '❤️',
      name: 'Red Heart',
      category: 'Hearts',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Red%20heart/3D/red_heart_3d.png',
    ),
    FluentEmojiItem(
      unicode: '💖',
      name: 'Sparkling Heart',
      category: 'Hearts',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Sparkling%20heart/3D/sparkling_heart_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🔥',
      name: 'Fire',
      category: 'Symbols',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Fire/3D/fire_3d.png',
    ),
    FluentEmojiItem(
      unicode: '✨',
      name: 'Sparkles',
      category: 'Symbols',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Sparkles/3D/sparkles_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🎉',
      name: 'Party Popper',
      category: 'Symbols',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Party%20popper/3D/party_popper_3d.png',
    ),
    FluentEmojiItem(
      unicode: '🚀',
      name: 'Rocket',
      category: 'Symbols',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Rocket/3D/rocket_3d.png',
    ),
    FluentEmojiItem(
      unicode: '💯',
      name: 'Hundred Points',
      category: 'Symbols',
      fluentUrl: 'https://cdn.jsdelivr.net/gh/microsoft/fluentui-emoji@main/assets/Hundred%20points/3D/hundred_points_3d.png',
    ),
  ];

  static FluentEmojiItem? findFluentEmojiByUnicode(String unicode) {
    for (final item in fluentEmojis) {
      if (item.unicode == unicode) return item;
    }
    return null;
  }
}
