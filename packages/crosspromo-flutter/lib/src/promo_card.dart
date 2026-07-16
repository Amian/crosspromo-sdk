import 'dart:async';

import 'package:flutter/material.dart';

import 'client.dart';
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
  int _loadGeneration = 0;

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

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (mounted && _card != null) {
      setState(() => _card = null);
    }
    try {
      final card = await CrossPromo.client.fetchCard(
        placement: widget.placement,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _card = card);
      widget.onLoaded?.call(card);
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        widget.onError?.call(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    if (card == null) return const SizedBox.shrink();
    return CrossPromoImpressionObserver(
      card: card,
      child: Semantics(
        label: 'Ad. ${card.appName}. ${card.tagline}',
        button: true,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => CrossPromo.client.open(card),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      card.iconUrl.toString(),
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.square(
                        dimension: 58,
                        child: ColoredBox(color: Color(0x11000000)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          card.tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Ad · Indie pick',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => CrossPromo.client.open(card),
                    child: Text(card.cta),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
