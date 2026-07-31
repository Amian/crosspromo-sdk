import 'package:flutter/painting.dart';

/// Pulls a card's icon into the image cache before the card is shown.
///
/// Prefetching the card JSON alone still leaves the icon downloading at the moment
/// the card appears, so it fades in a beat late. Warming it here means the bytes are
/// already decoded and waiting.
typedef CrossPromoIconWarmer = void Function(Uri iconUrl);

/// Resolves through the same shared [ImageCache] the card widget reads from, so the
/// widget hits the cache rather than the network.
///
/// Deliberately silent and non-blocking: this runs when nothing is on screen, so a
/// failure here must never surface. The card falls back to loading the icon itself,
/// which is exactly what it did before.
void warmCrossPromoIcon(Uri iconUrl) {
  if (iconUrl.toString().isEmpty) return;
  try {
    final stream =
        NetworkImage(iconUrl.toString()).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) {
        // The cache keeps its own reference; this handle is ours to release.
        imageInfo.dispose();
        stream.removeListener(listener);
      },
      onError: (_, __) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  } on Object {
    // No binding (plain unit tests) or an unusable URL. Nothing to do.
  }
}
