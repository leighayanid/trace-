import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app/theme/theme.dart';
import 'package:trace/shared/widgets/trace_nav_bar.dart';

/// The nav bar fits every phone TRACE is likely to meet, at the text sizes
/// people actually set, and stays one group on a wide screen.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    double textScale = 1,
    ValueChanged<int>? onSelect,
    VoidCallback? onPlus,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TraceTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            // A gesture-navigation inset, as on a current Android phone.
            padding: const EdgeInsets.only(bottom: 24),
          ),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: TraceNavBar(
            currentIndex: 0,
            onSelect: onSelect ?? (_) {},
            onPlus: onPlus ?? () {},
          ),
        ),
      ),
    );
  }

  for (final width in [320.0, 384.0, 1024.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('lays out at ${width.toInt()}dp, ${scale}x text',
          (tester) async {
        await pump(tester, width: width, textScale: scale);
        // An overflow is reported as a FlutterError, which fails the test.
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(TraceNavBar)).height,
          TraceSize.navBar + 24 + 1, // bar + system inset + top hairline
        );
      });
    }
  }

  testWidgets('destinations stay grouped on a wide screen', (tester) async {
    await pump(tester, width: 1024);
    final row = find.descendant(
      of: find.byType(TraceNavBar),
      matching: find.byType(Row),
    );
    expect(tester.getSize(row.first).width, TraceSize.navMaxWidth);
    expect(tester.getCenter(row.first).dx, 512);
  });

  testWidgets('tabs and + respond to taps', (tester) async {
    int? selected;
    var plus = 0;
    await pump(
      tester,
      width: 384,
      onSelect: (i) => selected = i,
      onPlus: () => plus++,
    );

    await tester.tap(find.text('Projects'));
    expect(selected, 2);

    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(plus, 1);
  });
}
