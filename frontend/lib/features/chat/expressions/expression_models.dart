enum ExpressionType {
  animatedEmoji,   // Lottie JSON
  animatedSticker, // WebP
  interactiveReaction, // Rive
  normalEmoji,     // Unicode / Fluent Emoji
}

/// 1. Animated Emoji (Lottie JSON)
class AnimatedEmojiItem {
  final String id;
  final String name;
  final String lottieUrl;
  final String animatedWebpUrl; // High-performance animated WebP for Web & mobile fallback
  final String unicodeFallback;

  const AnimatedEmojiItem({
    required this.id,
    required this.name,
    required this.lottieUrl,
    this.animatedWebpUrl = '',
    required this.unicodeFallback,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lottie_url': lottieUrl,
    'animated_webp_url': animatedWebpUrl,
    'unicode': unicodeFallback,
  };
}

/// 2. Animated Sticker (WebP)
class AnimatedStickerItem {
  final String id;
  final String name;
  final String webpUrl;
  final String packId;
  final String packName;
  final bool isAnimated;

  const AnimatedStickerItem({
    required this.id,
    required this.name,
    required this.webpUrl,
    required this.packId,
    required this.packName,
    this.isAnimated = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'webp_url': webpUrl,
    'pack_id': packId,
    'pack_name': packName,
    'is_animated': isAnimated,
  };
}

/// 3. Interactive Reaction (Rive)
class InteractiveReactionItem {
  final String id;
  final String name;
  final String riveUrl;
  final String? artboard;
  final String? stateMachineName;
  final String? triggerName;
  final String unicodeFallback;

  const InteractiveReactionItem({
    required this.id,
    required this.name,
    required this.riveUrl,
    this.artboard,
    this.stateMachineName,
    this.triggerName,
    required this.unicodeFallback,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rive_url': riveUrl,
    if (artboard != null) 'artboard': artboard,
    if (stateMachineName != null) 'state_machine': stateMachineName,
    if (triggerName != null) 'trigger': triggerName,
    'unicode': unicodeFallback,
  };
}

/// 4. Normal Emoji (Unicode / Fluent Emoji)
class FluentEmojiItem {
  final String unicode;
  final String name;
  final String category;
  final String fluentUrl;

  const FluentEmojiItem({
    required this.unicode,
    required this.name,
    required this.category,
    required this.fluentUrl,
  });

  Map<String, dynamic> toJson() => {
    'unicode': unicode,
    'name': name,
    'category': category,
    'fluent_url': fluentUrl,
  };
}
