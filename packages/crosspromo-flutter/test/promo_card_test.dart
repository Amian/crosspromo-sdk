import 'package:crosspromo_sdk/src/models.dart';
import 'package:crosspromo_sdk/src/promo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final card = PromoCardData(
    cardId: 'card_1',
    appName: 'Chemistry Solver AI - Flasky',
    iconUrl: Uri.parse('https://invalid.example/icon.png'),
    tagline: 'Discover another independent app',
    cta: 'Get',
    clickUrl: Uri.parse('https://example.test/click'),
    impressionToken: 'imp_1',
    expiresAt: DateTime.utc(2099),
  );

  testWidgets('keeps its intrinsic height inside a tall host slot',
      (tester) async {
    await tester.pumpWidget(_host(card: card, width: 360, height: 220));

    expect(tester.takeException(), isNull);
    _expectContent(card);

    final cardRect = tester.getRect(
      find.byKey(ValueKey<String>('crosspromo-card-${card.cardId}')),
    );
    final observerRect =
        tester.getRect(find.byType(CrossPromoImpressionObserver));
    expect(cardRect.height, inInclusiveRange(84, 160));
    expect(cardRect.width, 360);
    expect(observerRect, cardRect);
  });

  testWidgets('stays readable on a narrow host with enlarged text',
      (tester) async {
    await tester.pumpWidget(
      _host(card: card, width: 320, height: 240, textScale: 1.3),
    );

    expect(tester.takeException(), isNull);
    _expectContent(card);

    final titleRect = tester.getRect(find.text(card.appName));
    final ctaRect = tester.getRect(find.text(card.cta));
    expect(titleRect.width, greaterThan(80));
    expect(ctaRect.right, lessThanOrEqualTo(320));
  });
}

Widget _host({
  required PromoCardData card,
  required double width,
  required double height,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: ThemeData(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
        ),
      ),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: PromoCardLayout(card: card, onTap: _noop),
          ),
        ),
      ),
    ),
  );
}

void _expectContent(PromoCardData card) {
  expect(find.text(card.appName), findsOneWidget);
  expect(find.text(card.tagline), findsOneWidget);
  expect(find.text('AD'), findsOneWidget);
  expect(find.text('Indie pick'), findsOneWidget);
  expect(find.text(card.cta), findsOneWidget);
}

void _noop() {}
