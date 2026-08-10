# Promo card redesign

Reference images for the icon-derived brand-accent promo cards
(`design/premium-ad-cards`).

Every card extracts the dominant color from the promoted app's icon and derives
its whole palette from it — surface wash, icon glow, `AD` chip, and CTA capsule —
automatically, per ad, in both light and dark themes, with no work for the host
developer.

## simulator-light-dark.png

The real SDK running in the iOS Simulator (iPhone 15 Pro). These are live
`PromoCard` widgets from `packages/crosspromo-flutter`, loading real App Store
icons from a local mock ad server. The top half is the light theme, the bottom
half is dark — rendered by the same code with no configuration.

Note **CoinSnap**: the gold accent holds in both themes, and the CTA ink flips
to dark on the bright gold (measured WCAG luminance), so the button never loses
contrast.

## color-system-matrix.png

The color system swept across six icon hues in both themes. Same math, six
icons. Yellow triggers the dark-ink CTA; the grayscale icon falls back to the
neutral palette with the system CTA color.

The accent is derived from the icon's dominant color rather than an average, so
the result stays vivid instead of turning to mud, and an icon with no usable
color falls back to the refined neutral palette. The same derivation runs on
iOS, Flutter, and React Native, so a card looks identical on all three.
