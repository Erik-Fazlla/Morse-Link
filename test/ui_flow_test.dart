import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morse/app.dart';

/// Phone-sized viewport (logical 392x850, like a Pixel).
Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home → receive: two keys type a sentence', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(const MorseApp());
    await tester.tap(find.byKey(const Key('home-receive')));
    await tester.pumpAndSettle();

    Future<void> key(String code) async {
      for (final s in code.split('')) {
        await tester
            .tap(find.byKey(Key(s == '.' ? 'keyer-dot' : 'keyer-dash')));
        await tester.pump();
      }
    }

    await key('....');
    expect(find.byKey(const Key('keyer-pending')), findsOneWidget);
    expect(
      (tester.widget(find.byKey(const Key('keyer-pending'))) as Text).data,
      'H',
    );
    await tester.tap(find.byKey(const Key('keyer-letter')));
    await key('..');
    await tester.tap(find.byKey(const Key('keyer-space')));
    await key('.--.');
    await tester.tap(find.byKey(const Key('keyer-letter')));
    await tester.pump();

    final rich = tester.widget<Text>(find.byKey(const Key('keyer-text')));
    expect(rich.textSpan!.toPlainText(), 'HI P▍');
    expect(tester.takeException(), isNull);
  });

  testWidgets('send: saved and recent start minimized; sheet is partial',
      (tester) async {
    await _phone(tester);
    await tester.pumpWidget(const MorseApp());
    await tester.tap(find.byKey(const Key('home-send')));
    await tester.pumpAndSettle();

    // Lists are not on the page — only two compact buttons.
    expect(find.byKey(const Key('send-saved-tile')), findsOneWidget);
    expect(find.byKey(const Key('send-history-tile')), findsOneWidget);
    expect(find.text('Saved messages'), findsNothing);
    // Start button pinned and visible without scrolling.
    expect(find.byKey(const Key('send-start')).hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('send-saved-tile')));
    await tester.pumpAndSettle();
    expect(find.text('Saved messages'), findsOneWidget);

    final sheet = tester.getRect(find.byType(DraggableScrollableSheet));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(sheet.height, lessThan(screen.height * 0.7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('screens render on a small phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0; // 360x640
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MorseApp());
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('home-receive')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-send')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('receive help alphabet fits on a narrow phone with big text',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 2.75; // ~327 wide, like the field report
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MorseApp());
    await tester.ensureVisible(find.byKey(const Key('home-receive')));
    await tester.tap(find.byKey(const Key('home-receive')));
    await tester.pumpAndSettle();
    // Button labels stay on one line (they wrapped as LET/TER before).
    for (final label in ['LETTER', 'SPACE']) {
      final line = tester.getSize(find.text(label));
      expect(line.height, lessThan(line.width), reason: '$label wrapped');
    }

    await tester.tap(find.byTooltip('How it works'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull); // receive screen itself

    // Longest codes: 0 (-----), J (.---), punctuation is excluded.
    await tester.scrollUntilVisible(
      find.byKey(const Key('alphabet-0')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alphabet-0')), findsOneWidget);
    expect(find.byKey(const Key('alphabet-J')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
