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

  testWidgets('stays readable under a full-width host button theme',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 220,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 112),
                child: PromoCardPresentation(card: card, onTap: _noop),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(card.appName), findsOneWidget);
    expect(find.text(card.tagline), findsOneWidget);
    expect(find.text('Ad · Indie pick'), findsOneWidget);
    expect(find.text(card.cta), findsOneWidget);

    final titleRect = tester.getRect(find.text(card.appName));
    final buttonRect =
        tester.getRect(find.widgetWithText(FilledButton, card.cta));
    expect(titleRect.width, greaterThan(80));
    expect(buttonRect.width, inInclusiveRange(56, 92));
    expect(buttonRect.right, lessThanOrEqualTo(360));
  });
}

void _noop() {}
