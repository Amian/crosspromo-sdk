import 'dart:async';

import 'package:flutter/material.dart';

import 'client.dart';
import 'icon_accent.dart';
import 'models.dart';

class PromoCard extends StatefulWidget {
  const PromoCard({
    required this.placement,
    super.key,
    this.onError,
    this.onLoaded,
  });

  final CrossPromoPlacement placement;
  final ValueChanged<Object>? onError;
  final ValueChanged<PromoCardData?>? onLoaded;

  @override
  State<PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<PromoCard> {
  PromoCardData? _card;
  IconAccent? _accent;
  int _loadGeneration = 0;
  ImageStream? _iconStream;
  ImageStreamListener? _iconListener;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PromoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) _load();
  }

  @override
  void dispose() {
    _stopIconStream();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    _stopIconStream();
    if (mounted && (_card != null || _accent != null)) {
      setState(() {
        _card = null;
        _accent = null;
      });
    }
    try {
      final card = await CrossPromo.client.fetchCard(
        placement: widget.placement,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _card = card);
      widget.onLoaded?.call(card);
      if (card != null) _resolveAccent(card, generation);
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        widget.onError?.call(error);
      }
    }
  }

  /// Resolves the icon through the shared image cache (the same provider the
  /// visible [Image.network] uses, so the icon is only fetched once) and
  /// derives the card's brand accent from it.
  void _resolveAccent(PromoCardData card, int generation) {
    final stream =
        NetworkImage(card.iconUrl.toString()).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (imageInfo, _) {
        final image = imageInfo.image.clone();
        imageInfo.dispose();
        unawaited(
          IconAccent.extract(image).then((accent) {
            image.dispose();
            if (!mounted || generation != _loadGeneration || accent == null) {
              return;
            }
            setState(() => _accent = accent);
          }),
        );
      },
      onError: (_, __) {},
    );
    _iconStream = stream;
    _iconListener = listener;
    stream.addListener(listener);
  }

  void _stopIconStream() {
    final stream = _iconStream;
    final listener = _iconListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _iconStream = null;
    _iconListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    if (card == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final darkTheme = theme.brightness == Brightness.dark;
    final palette = _CardPalette.from(_accent, theme);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return CrossPromoImpressionObserver(
      card: card,
      child: Semantics(
        label: 'Ad. ${card.appName}. ${card.tagline}',
        button: true,
        child: _Entrance(
          key: ValueKey<String>(card.cardId),
          enabled: !reduceMotion,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.hairline),
              boxShadow: darkTheme
                  ? const <BoxShadow>[]
                  : const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => CrossPromo.client.open(card),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
                      child: Row(
                        children: [
                          _IconWithGlow(
                            url: card.iconUrl.toString(),
                            glow: palette.glow,
                            darkTheme: darkTheme,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.appName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        card.tagline,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 13,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _CtaButton(
                                      label: card.cta,
                                      palette: palette,
                                      onTap: () => CrossPromo.client.open(card),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: palette.chipBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AD',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            height: 1,
                            color: palette.chipText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One orchestrated entrance: the card fades in and rises as it appears.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.enabled, required this.child, super.key});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - progress)),
          child: child,
        ),
      ),
    );
  }
}

class _IconWithGlow extends StatelessWidget {
  const _IconWithGlow({
    required this.url,
    required this.glow,
    required this.darkTheme,
  });

  final String url;
  final Color? glow;
  final bool darkTheme;

  @override
  Widget build(BuildContext context) {
    final glow = this.glow;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: glow == null
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                    color: glow, blurRadius: 9, offset: const Offset(0, 3)),
              ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: darkTheme ? const Color(0x29FFFFFF) : const Color(0x14000000),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.square(
            dimension: 56,
            child: ColoredBox(color: Color(0x11000000)),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final _CardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.ctaTop, palette.ctaBottom],
        ),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: palette.ctaShadow,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.onCta,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolved colors for one theme. Accent-derived when the icon yields a brand
/// color, otherwise a refined neutral look driven by the host theme.
class _CardPalette {
  const _CardPalette({
    required this.surface,
    required this.hairline,
    required this.chipBackground,
    required this.chipText,
    required this.ctaTop,
    required this.ctaBottom,
    required this.onCta,
    required this.ctaShadow,
    required this.glow,
  });

  factory _CardPalette.from(IconAccent? accent, ThemeData theme) {
    final darkTheme = theme.brightness == Brightness.dark;
    final base = darkTheme ? const Color(0xFF1C1C20) : Colors.white;
    if (accent == null) {
      final primary = theme.colorScheme.primary;
      return _CardPalette(
        surface: base,
        hairline: theme.colorScheme.outlineVariant,
        chipBackground: theme.colorScheme.onSurface.withAlpha(20),
        chipText: theme.colorScheme.onSurfaceVariant,
        ctaTop: primary,
        ctaBottom: primary,
        onCta: theme.colorScheme.onPrimary,
        ctaShadow: primary.withAlpha(darkTheme ? 96 : 66),
        glow: null,
      );
    }
    final cta = accent.ctaColor(darkTheme: darkTheme);
    final ctaHsv = HSVColor.fromColor(cta);
    return _CardPalette(
      surface: Color.alphaBlend(accent.washColor(darkTheme: darkTheme), base),
      hairline: accent.hairlineColor(darkTheme: darkTheme),
      chipBackground: accent.chipBackgroundColor(darkTheme: darkTheme),
      chipText: accent.chipTextColor(darkTheme: darkTheme),
      ctaTop: ctaHsv
          .withValue((ctaHsv.value + 0.05).clamp(0.0, 1.0).toDouble())
          .toColor(),
      ctaBottom: ctaHsv
          .withValue((ctaHsv.value - 0.05).clamp(0.0, 1.0).toDouble())
          .toColor(),
      onCta: accent.onCtaColor(darkTheme: darkTheme),
      ctaShadow: cta.withAlpha(darkTheme ? 107 : 71),
      glow: accent.glowColor(darkTheme: darkTheme),
    );
  }

  final Color surface;
  final Color hairline;
  final Color chipBackground;
  final Color chipText;
  final Color ctaTop;
  final Color ctaBottom;
  final Color onCta;
  final Color ctaShadow;
  final Color? glow;
}

class CrossPromoImpressionObserver extends StatefulWidget {
  const CrossPromoImpressionObserver({
    required this.card,
    required this.child,
    super.key,
  });

  final PromoCardData card;
  final Widget child;

  @override
  State<CrossPromoImpressionObserver> createState() =>
      _CrossPromoImpressionObserverState();
}

class _CrossPromoImpressionObserverState
    extends State<CrossPromoImpressionObserver> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _visibleSince;
  double _highestFraction = 0;
  bool _reported = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _sample(),
    );
  }

  @override
  void didUpdateWidget(CrossPromoImpressionObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.impressionToken != widget.card.impressionToken) {
      _visibleSince = null;
      _highestFraction = 0;
      _reported = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) {
      _visibleSince = null;
    }
  }

  void _sample() {
    if (!mounted || _reported || _lifecycle != AppLifecycleState.resumed) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      _visibleSince = null;
      return;
    }
    final origin = renderObject.localToGlobal(Offset.zero);
    final widgetRect = origin & renderObject.size;
    final view = View.of(context);
    final screenRect =
        Offset.zero & (view.physicalSize / view.devicePixelRatio);
    final intersection = widgetRect.intersect(screenRect);
    final fraction = widgetRect.size.isEmpty || intersection.isEmpty
        ? 0.0
        : (intersection.width * intersection.height) /
            (widgetRect.width * widgetRect.height);
    if (fraction < 0.5) {
      _visibleSince = null;
      _highestFraction = 0;
      return;
    }
    _highestFraction =
        fraction > _highestFraction ? fraction : _highestFraction;
    _visibleSince ??= DateTime.now();
    final duration = DateTime.now().difference(_visibleSince!);
    if (duration >= const Duration(seconds: 1)) {
      _reported = true;
      unawaited(
        CrossPromo.client.recordImpression(
          widget.card,
          visibleFraction: _highestFraction,
          duration: duration,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
